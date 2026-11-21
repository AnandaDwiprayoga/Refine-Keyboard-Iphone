import SwiftUI
import UIKit

/// Action-only keyboard: style buttons, a preview of the result, and the few keys
/// you need around it. Typing itself happens on Apple's keyboard (switch with 🌐).
struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel
    let controller: UIInputViewController

    var body: some View {
        VStack(spacing: 6) {
            topBar
            if model.showSettings {
                SettingsPanel(model: model)
            } else {
                styleRow
                preview
                bottomRow
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Rows

    private var topBar: some View {
        HStack(spacing: 8) {
            if model.needsGlobe {
                GlobeKey(controller: controller)
                    .frame(width: 34, height: 30)
            }
            Text(model.showSettings ? "Refine settings" : model.sourceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                if model.showSettings { model.showSettings = false } else { model.openSettings() }
            } label: {
                Image(systemName: model.showSettings ? "xmark.circle.fill" : "gearshape")
                    .font(.system(size: 17))
                    .frame(width: 34, height: 30)
            }
            .tint(.primary)
            .accessibilityLabel(model.showSettings ? "Close settings" : "Settings")
        }
        .frame(height: 30)
    }

    private var styleRow: some View {
        HStack(spacing: 5) {
            ForEach(KeyboardModel.actions) { action in
                Button { model.run(action) } label: {
                    VStack(spacing: 1) {
                        Text(action.icon).font(.system(size: 19))
                        Text(action.label).font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(KeyStyle(highlighted: isWorking(action)))
                .disabled(isBusy)
                .accessibilityLabel(action.label)
            }
        }
    }

    private var preview: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.55))
            ScrollView {
                previewContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var previewContent: some View {
        if let error = model.startupError {
            Text(error).font(.callout).foregroundStyle(.red)
        } else if !model.hasFullAccess {
            VStack(alignment: .leading, spacing: 4) {
                Text("Allow Full Access to use Refine").font(.callout.weight(.semibold))
                Text("Settings → General → Keyboard → Keyboards → Refine → Allow Full Access. Refine needs it to reach Groq and read the clipboard. It never sends what you type unless you tap a button.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else if !model.hasAPIKey, case .idle = model.phase {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add your Groq key").font(.callout.weight(.semibold))
                Text("Copy your key from console.groq.com/keys, then tap ⚙ → Paste key.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            switch model.phase {
            case .idle:
                Text("Select text or type, then tap a style. 🇮🇩 translates the selection, or a message you copied.")
                    .font(.callout).foregroundStyle(.secondary)
            case .working(let action):
                HStack(spacing: 8) {
                    ProgressView()
                    Text(action.mode == .translate ? "Translating…" : "Refining…")
                        .font(.callout).foregroundStyle(.secondary)
                }
            case .result(let action, let source, let text):
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(action.icon) \(action.label) · from \(source.kind.label.lowercased())")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(text).font(.callout).textSelection(.enabled)
                }
            case .failed(let message):
                Text(message).font(.callout).foregroundStyle(.red)
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 5) {
            if model.canReplace {
                Button("Replace") { model.replace() }
                    .buttonStyle(KeyStyle(primary: true))
            } else if model.canInsertTranslation {
                Button("Insert") { model.insertTranslation() }
                    .buttonStyle(KeyStyle())
            }
            if case .result = model.phase {
                Button(model.copied ? "Copied" : "Copy") { model.copyResult() }
                    .buttonStyle(KeyStyle())
                Button { model.dismissResult() } label: { Image(systemName: "xmark") }
                    .buttonStyle(KeyStyle(width: 44))
                    .accessibilityLabel("Dismiss")
            } else {
                if model.canUndo {
                    Button { model.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(KeyStyle())
                }
                Button("space") { model.insertSpace() }
                    .buttonStyle(KeyStyle())
            }
            Button { model.deleteBackward() } label: { Image(systemName: "delete.left") }
                .buttonStyle(KeyStyle(width: 48))
                .accessibilityLabel("Delete")
            Button { model.insertReturn() } label: { Image(systemName: "return") }
                .buttonStyle(KeyStyle(width: 48))
                .accessibilityLabel("Return")
        }
        .frame(height: 42)
    }

    // MARK: Helpers

    private var isBusy: Bool {
        if case .working = model.phase { return true }
        return false
    }

    private func isWorking(_ action: KeyboardModel.Action) -> Bool {
        if case .working(let current) = model.phase { return current == action }
        return false
    }
}

/// Settings live in the keyboard because the host app shares nothing with it.
/// A keyboard can't type into its own text fields, so values come from the clipboard.
private struct SettingsPanel: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                row(title: "Groq API key",
                    detail: model.hasAPIKey ? "Saved ✓" : "Not set. Copy it from console.groq.com/keys.") {
                    Button("Paste key") { model.pasteAPIKey() }.buttonStyle(KeyStyle(primary: !model.hasAPIKey))
                    if model.hasAPIKey {
                        Button("Remove") { model.removeAPIKey() }.buttonStyle(KeyStyle())
                    }
                }
                row(title: "Never send these words",
                    detail: model.hiddenTermCount == 0
                        ? "None. Copy a comma-separated list (client names, code names)."
                        : "\(model.hiddenTermCount) word(s) hidden before sending.") {
                    Button("Paste list") { model.pasteHiddenWords() }.buttonStyle(KeyStyle())
                    if model.hiddenTermCount > 0 {
                        Button("Clear") { model.clearHiddenWords() }.buttonStyle(KeyStyle())
                    }
                }
                if let message = model.settingsMessage {
                    HStack {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                        if model.offerClearClipboard {
                            Button("Clear clipboard") { model.clearClipboard() }
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.55))
        )
        .frame(maxHeight: .infinity)
    }

    private func row<Buttons: View>(title: String, detail: String, @ViewBuilder buttons: () -> Buttons) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            buttons().frame(height: 36)
        }
    }
}

/// Looks like a system keyboard key, in light and dark mode.
struct KeyStyle: ButtonStyle {
    var primary = false
    var highlighted = false
    var width: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: primary ? .semibold : .regular))
            .foregroundStyle(primary ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill(pressed: configuration.isPressed))
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
            )
    }

    private func fill(pressed: Bool) -> Color {
        if primary { return pressed ? Color.accentColor.opacity(0.7) : Color.accentColor }
        if pressed || highlighted { return Color(uiColor: .systemGray3) }
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white })
    }
}
