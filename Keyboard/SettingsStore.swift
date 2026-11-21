import Foundation
import Security

/// The keyboard's own settings. Nothing is shared with the host app (no App Groups,
/// no keychain sharing), so SideStore's re-signing can't break it.
/// The API key lives in this extension's keychain; hidden words in its UserDefaults.
enum SettingsStore {
    private static let service = "RefineKeyboard"
    private static let keyAccount = "groq-api-key"
    private static let hiddenTermsKey = "hiddenTerms"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: keyAccount]
    }

    static func apiKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    /// Saves the key; an empty string deletes it. Returns false if the keychain refused.
    @discardableResult
    static func setAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        SecItemDelete(baseQuery as CFDictionary)
        guard !trimmed.isEmpty else { return true }
        var query = baseQuery
        query[kSecValueData as String] = Data(trimmed.utf8)
        // Readable while the phone is locked after first unlock, never synced or backed up elsewhere.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrLabel as String] = "Refine keyboard Groq API key"
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// "Never send these words": comma or newline separated, same format as PopClip's setting.
    static var hiddenTerms: String {
        get { UserDefaults.standard.string(forKey: hiddenTermsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: hiddenTermsKey) }
    }

    static var hiddenTermCount: Int {
        hiddenTerms
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    /// A Groq key looks like gsk_ followed by a long token.
    static func looksLikeGroqKey(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("gsk_") && trimmed.count >= 30 && !trimmed.contains(where: \.isWhitespace)
    }
}
