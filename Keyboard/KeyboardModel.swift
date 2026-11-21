import RefineCore
import UIKit

/// The keyboard's state: what text a button acts on, the request, the result,
/// and replacing/undoing it in the host app's text field.
@MainActor
final class KeyboardModel: ObservableObject {
    struct Action: Identifiable, Hashable {
        let id: String
        let icon: String
        let label: String
        let mode: Refiner.Mode
    }

    /// The PopClip buttons, same style ids as prompt.js.
    static let actions = [
        Action(id: "me", icon: "✨", label: "My style", mode: .rewrite(style: "me")),
        Action(id: "polite", icon: "🙏", label: "Polite", mode: .rewrite(style: "polite")),
        Action(id: "short", icon: "✂️", label: "Short", mode: .rewrite(style: "short")),
        Action(id: "fix", icon: "✅", label: "Fix", mode: .rewrite(style: "fix")),
        Action(id: "translate", icon: "🇮🇩", label: "Bahasa", mode: .translate),
    ]

    enum SourceKind: Equatable {
        case selection, beforeCursor, clipboard

        var label: String {
            switch self {
            case .selection: return "Selected"
            case .beforeCursor: return "Text before cursor"
            case .clipboard: return "Clipboard"
            }
        }
    }

    struct Source: Equatable {
        let kind: SourceKind
        let text: String
    }

    enum Phase: Equatable {
        case idle
        case working(Action)
        case result(Action, source: Source, text: String)
        case failed(String)
    }

    /// What was put in the field by the last Replace, so Undo can take it back.
    private struct Replacement {
        let inserted: String
        let original: String
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var sourceLabel = ""
    @Published private(set) var canUndo = false
    @Published private(set) var copied = false
    @Published var showSettings = false
    @Published private(set) var hasAPIKey = SettingsStore.apiKey() != nil
    @Published private(set) var hiddenTermCount = SettingsStore.hiddenTermCount
    @Published private(set) var settingsMessage: String?
    @Published private(set) var offerClearClipboard = false

    private weak var controller: UIInputViewController?
    private var refiner: Refiner?
    private var loadError: String?
    private var work: Task<Void, Never>?
    private var lastReplacement: Replacement?

    init(controller: UIInputViewController) {
        self.controller = controller
        do {
            guard let dir = RefineJS.defaultDirectory() else {
                throw GroqError(status: nil, message: "Refine's JS isn't bundled in the keyboard. Rebuild the app.")
            }
            refiner = try Refiner(js: RefineJS(directory: dir))
        } catch {
            loadError = error.localizedDescription
        }
    }

    var hasFullAccess: Bool { controller?.hasFullAccess ?? false }
    var needsGlobe: Bool { controller?.needsInputModeSwitchKey ?? true }
    var startupError: String? { loadError }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }

    // MARK: Source text

    /// Rewrites act on the selection, else on what's before the cursor.
    /// 🇮🇩 acts on the selection, else the clipboard (a message you copied), else what's before the cursor.
    private func source(for action: Action, readClipboard: Bool) -> Source? {
        if let selected = proxy?.selectedText, !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Source(kind: .selection, text: selected)
        }
        if action.mode == .translate, readClipboard, hasFullAccess,
           let clip = UIPasteboard.general.string, !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Source(kind: .clipboard, text: clip)
        }
        if let before = proxy?.documentContextBeforeInput, !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Source(kind: .beforeCursor, text: before)
        }
        return nil
    }

    /// Updates the label that says what a style button would use. Never reads the
    /// clipboard (that's only done when you tap 🇮🇩).
    func textChanged() {
        copied = false
        if let selected = proxy?.selectedText, !selected.isEmpty {
            sourceLabel = "Selected · \(selected.count) chars"
        } else if let before = proxy?.documentContextBeforeInput, !before.trimmingCharacters(in: .whitespaces).isEmpty {
            sourceLabel = "Before cursor · \(before.count) chars"
        } else {
            sourceLabel = "Select or type some text"
        }
        // Undo only works while the text we inserted is still right before the cursor.
        if let last = lastReplacement, !(proxy?.documentContextBeforeInput ?? "").hasSuffix(last.inserted) {
            lastReplacement = nil
            canUndo = false
        }
    }

    // MARK: Actions

    func run(_ action: Action) {
        work?.cancel()
        copied = false
        guard let refiner else { phase = .failed(loadError ?? "Refine couldn't start."); return }
        guard hasFullAccess else {
            phase = .failed("Turn on Allow Full Access for Refine so it can reach Groq.")
            return
        }
        guard let apiKey = SettingsStore.apiKey() else {
            hasAPIKey = false
            phase = .failed("Add your Groq key first: copy it, then tap ⚙ → Paste key.")
            return
        }
        guard let source = source(for: action, readClipboard: true) else {
            phase = .failed(action.mode == .translate
                ? "Select text or copy a message first."
                : "Select text or type something first.")
            return
        }

        phase = .working(action)
        let terms = SettingsStore.hiddenTerms
        work = Task { [weak self] in
            do {
                let output = try await refiner.run(source.text, mode: action.mode, hiddenTerms: terms, apiKey: apiKey)
                guard let self, !Task.isCancelled else { return }
                guard let output else {
                    self.phase = .failed(action.mode == .translate ? "Nothing to translate." : "Nothing to refine.")
                    return
                }
                let text = action.mode == .translate
                    ? output
                    : ((try? refiner.js.keepSurroundingWhitespace(original: source.text, rewritten: output)) ?? output)
                self.phase = .result(action, source: source, text: text)
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                if let groq = error as? GroqError, groq.status == 401 {
                    self.phase = .failed("Groq rejected the key. Copy a new one and tap ⚙ → Paste key.")
                } else {
                    self.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Rewrites can replace the text they came from. Translations are only shown and copied.
    var canReplace: Bool {
        if case .result(let action, let source, _) = phase {
            return action.mode != .translate && source.kind != .clipboard
        }
        return false
    }

    var canInsertTranslation: Bool {
        if case .result(let action, _, _) = phase { return action.mode == .translate }
        return false
    }

    func replace() {
        guard case .result(_, let source, let text) = phase, let proxy else { return }
        switch source.kind {
        case .selection:
            // Typing over a selection replaces it.
            guard proxy.selectedText == source.text else {
                phase = .failed("The selection changed. Select the text again and retry.")
                return
            }
            proxy.insertText(text)
        case .beforeCursor:
            guard proxy.documentContextBeforeInput == source.text else {
                phase = .failed("The text changed. Tap the style again.")
                return
            }
            for _ in 0..<source.text.count { proxy.deleteBackward() }
            proxy.insertText(text)
        case .clipboard:
            return
        }
        lastReplacement = Replacement(inserted: text, original: source.text)
        canUndo = true
        phase = .idle
        textChanged()
    }

    func insertTranslation() {
        guard case .result(_, _, let text) = phase else { return }
        proxy?.insertText(text)
        phase = .idle
    }

    func undo() {
        guard let last = lastReplacement, let proxy,
              (proxy.documentContextBeforeInput ?? "").hasSuffix(last.inserted) else {
            lastReplacement = nil
            canUndo = false
            return
        }
        for _ in 0..<last.inserted.count { proxy.deleteBackward() }
        proxy.insertText(last.original)
        lastReplacement = nil
        canUndo = false
        textChanged()
    }

    func copyResult() {
        guard case .result(_, _, let text) = phase, hasFullAccess else { return }
        UIPasteboard.general.string = text
        copied = true
    }

    func dismissResult() {
        work?.cancel()
        phase = .idle
        copied = false
    }

    // MARK: Keys

    func deleteBackward() { proxy?.deleteBackward() }
    func insertSpace() { proxy?.insertText(" ") }
    func insertReturn() { proxy?.insertText("\n") }
    func nextKeyboard() { controller?.advanceToNextInputMode() }

    // MARK: Settings

    func openSettings() {
        settingsMessage = nil
        offerClearClipboard = false
        showSettings = true
    }

    func pasteAPIKey() {
        offerClearClipboard = false
        guard hasFullAccess else { settingsMessage = "Turn on Allow Full Access first."; return }
        let clip = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard SettingsStore.looksLikeGroqKey(clip) else {
            settingsMessage = "The clipboard doesn't hold a Groq key (it starts with gsk_). Copy it from console.groq.com/keys."
            return
        }
        if SettingsStore.setAPIKey(clip) {
            hasAPIKey = SettingsStore.apiKey() != nil
            settingsMessage = hasAPIKey ? "Key saved on this iPhone." : "The keychain didn't keep the key."
            offerClearClipboard = hasAPIKey
            if case .failed = phase { phase = .idle }
        } else {
            settingsMessage = "The keychain refused to save the key."
        }
    }

    func removeAPIKey() {
        SettingsStore.setAPIKey("")
        hasAPIKey = false
        settingsMessage = "Key removed."
    }

    func clearClipboard() {
        UIPasteboard.general.string = ""
        offerClearClipboard = false
        settingsMessage = "Clipboard cleared."
    }

    func pasteHiddenWords() {
        guard hasFullAccess else { settingsMessage = "Turn on Allow Full Access first."; return }
        let clip = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clip.isEmpty else { settingsMessage = "Copy your words first, separated by commas."; return }
        guard !SettingsStore.looksLikeGroqKey(clip) else { settingsMessage = "That's your API key, not a word list."; return }
        SettingsStore.hiddenTerms = clip
        hiddenTermCount = SettingsStore.hiddenTermCount
        settingsMessage = "Saved \(hiddenTermCount) hidden word(s)."
    }

    func clearHiddenWords() {
        SettingsStore.hiddenTerms = ""
        hiddenTermCount = 0
        settingsMessage = "Hidden words cleared."
    }
}
