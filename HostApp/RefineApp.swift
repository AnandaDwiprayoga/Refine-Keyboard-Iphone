import SwiftUI

@main
struct RefineApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

/// The host app only exists because iOS installs keyboards inside an app.
/// It explains the setup and gives you a box to try the keyboard. It stores nothing.
struct SetupView: View {
    @State private var tryText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Turn rough drafts into natural English, or translate a message into Bahasa Indonesia, from any text field.")
                        .foregroundStyle(.secondary)

                    section("1. Add the keyboard") {
                        step("Tap **Open Settings** below, then **Keyboards**.")
                        step("Turn on **Refine**, then **Allow Full Access**.")
                        step("Refine needs Full Access to reach Groq. It sends nothing until you tap a button.")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .buttonStyle(.bordered)
                    }

                    section("2. Add your Groq key") {
                        step("Copy your key from **console.groq.com/keys** (it starts with `gsk_`).")
                        step("In the box below, switch to Refine with 🌐, tap ⚙ and **Paste key**.")
                        step("The key stays in the keyboard's keychain on this iPhone.")
                    }

                    section("3. Try it") {
                        TextField("e.g. td aku udh cek, tp blm fix ya", text: $tryText, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($focused)
                            // Autocorrect would "fix" Bahasa slang into English words before Refine sees it.
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        Text("Type with Apple's keyboard, switch to Refine with 🌐, tap ✨. Check the preview, then **Replace**. Select text first to refine just that part.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    section("Buttons") {
                        legend("✨", "My style: your own voice, from your style profile")
                        legend("🙏", "Polite: softer and more diplomatic")
                        legend("✂️", "Short: concise, keeps every fact")
                        legend("✅", "Fix: translates Bahasa and fixes grammar only")
                        legend("🇮🇩", "Bahasa: translates the selection, or a message you copied. Never replaces anything.")
                    }

                    section("Privacy") {
                        Text("Refine sends nothing while you type. Only when you tap a button does it send that text to Groq, after hiding links, emails, keys, numbers, code and your hidden words. Full Access is needed for the network and the clipboard.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Refine")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func step(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.subheadline)
    }

    private func legend(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(icon)
            Text(text).font(.subheadline)
        }
    }
}
