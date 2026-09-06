import AppKit
import Foundation
import Security

enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case openRouter = "OpenRouter"
    case ollama = "Ollama"
    case lmStudio = "LM Studio"
    var id: String { rawValue }
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16?
    var modifiers: UInt
    var rightModifierChord: Bool

    static let defaultShortcut = Shortcut(keyCode: nil, modifiers: 0, rightModifierChord: true)

    var displayName: String {
        if rightModifierChord { return "Right Command + Right Option" }
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        if let keyCode { parts.append(KeyNames.name(for: keyCode)) }
        return parts.joined()
    }
}

enum KeyNames {
    private static let names: [UInt16: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V",
        11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 18:"1", 19:"2", 20:"3",
        21:"4", 22:"6", 23:"5", 24:"=", 25:"9", 26:"7", 27:"-", 28:"8", 29:"0", 31:"O",
        32:"U", 34:"I", 35:"P", 37:"L", 38:"J", 40:"K", 45:"N", 46:"M", 49:"Space",
        36:"Return", 48:"Tab", 51:"Delete", 53:"Escape"
    ]
    static func name(for code: UInt16) -> String { names[code] ?? "Key \(code)" }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var provider: ProviderKind { didSet { save() } }
    @Published var model: String { didSet { save() } }
    @Published var ollamaURL: String { didSet { save() } }
    @Published var lmStudioURL: String { didSet { save() } }
    @Published var shortcut: Shortcut { didSet { save() } }
    @Published var onboardingComplete: Bool { didSet { save() } }
    @Published var apiKey: String { didSet { Keychain.save(apiKey, account: "openrouter") } }

    private let defaults = UserDefaults.standard
    private var loading = true

    init() {
        provider = ProviderKind(rawValue: defaults.string(forKey: "provider") ?? "") ?? .openRouter
        model = defaults.string(forKey: "model") ?? "openai/gpt-4.1-mini"
        ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://127.0.0.1:11434"
        lmStudioURL = defaults.string(forKey: "lmStudioURL") ?? "http://127.0.0.1:1234"
        onboardingComplete = defaults.bool(forKey: "onboardingComplete")
        if let data = defaults.data(forKey: "shortcut"), let decoded = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = decoded
        } else {
            shortcut = .defaultShortcut
        }
        apiKey = Keychain.load(account: "openrouter") ?? ""
        loading = false
    }

    func applyProviderDefaults(_ newProvider: ProviderKind) {
        provider = newProvider
        switch newProvider {
        case .openRouter: model = "openai/gpt-4.1-mini"
        case .ollama: model = "llama3.2"
        case .lmStudio: model = "local-model"
        }
    }

    private func save() {
        guard !loading else { return }
        defaults.set(provider.rawValue, forKey: "provider")
        defaults.set(model, forKey: "model")
        defaults.set(ollamaURL, forKey: "ollamaURL")
        defaults.set(lmStudioURL, forKey: "lmStudioURL")
        defaults.set(onboardingComplete, forKey: "onboardingComplete")
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut")
    }
}

enum Keychain {
    static func save(_ value: String, account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "GrammarBar",
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "GrammarBar",
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
