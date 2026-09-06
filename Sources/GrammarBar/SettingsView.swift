import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let requestAccessibility: () -> Void
    @State private var recording = false

    var body: some View {
        Group {
            if settings.onboardingComplete { configuration }
            else { onboarding }
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.primary)
        .preferredColorScheme(.light)
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Image(systemName: "text.cursor").font(.system(size: 48, weight: .light))
            Text("Write cleanly, anywhere.").font(.system(size: 34, weight: .bold))
            Text("Select text—or just place your cursor in a text field—then press Right Command + Right Option. GrammarBar corrects it in place.")
                .font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Label("Lives quietly in the menu bar", systemImage: "menubar.rectangle")
                Label("Works with OpenRouter, Ollama, and LM Studio", systemImage: "cpu")
                Label("Your OpenRouter key stays in Keychain", systemImage: "lock")
            }.font(.body)
            Spacer()
            HStack {
                Button("Grant Accessibility Access") { requestAccessibility() }
                Spacer()
                Button("Continue") { settings.onboardingComplete = true }.buttonStyle(.borderedProminent)
            }
        }.padding(40)
    }

    private var configuration: some View {
        Form {
            Section("AI provider") {
                Picker("Provider", selection: Binding(get: { settings.provider }, set: { settings.applyProviderDefaults($0) })) {
                    ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                TextField("Model", text: $settings.model)
                if settings.provider == .openRouter {
                    SecureField("OpenRouter API key", text: $settings.apiKey)
                    Text("Use any model ID available on OpenRouter.").font(.caption).foregroundStyle(.secondary)
                } else if settings.provider == .ollama {
                    TextField("Ollama server", text: $settings.ollamaURL)
                } else {
                    TextField("LM Studio server", text: $settings.lmStudioURL)
                }
            }
            Section("Keyboard shortcut") {
                HStack {
                    Text(settings.shortcut.displayName).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(recording ? "Press shortcut…" : "Record") { recording.toggle() }
                    Button("Reset") { settings.shortcut = .defaultShortcut }
                }
                ShortcutRecorder(shortcut: $settings.shortcut, recording: $recording).frame(height: 1)
                Text("The default chord uses the right-side Command and Option keys only.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Permissions") {
                HStack {
                    Text("Accessibility lets GrammarBar read and update the focused text field.")
                    Spacer()
                    Button("Open prompt") { requestAccessibility() }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
