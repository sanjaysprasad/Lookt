import Security
import Foundation

/// Stores enrolled face embeddings (NOT raw images — raw frames are
/// discarded right after embedding extraction) in the macOS Keychain.
/// Everything stays on-device; nothing is ever transmitted.
enum KeychainStore {
    private static let service = "com.lookt.embeddings"
    private static let account = "enrolled-faces"

    static func saveEmbeddings(_ embeddings: [FaceEmbedding]) -> Bool {
        guard let data = try? JSONEncoder().encode(embeddings) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary) // clear any prior enrollment

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func loadEmbeddings() -> [FaceEmbedding] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let embeddings = try? JSONDecoder().decode([FaceEmbedding].self, from: data) else {
            return []
        }
        return embeddings
    }

    static func hasEnrollment() -> Bool {
        !loadEmbeddings().isEmpty
    }

    static func clearEnrollment() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Login password is stored separately, only if the user explicitly
    /// opts in to auto-fill-on-match. Uses the standard internet/generic
    /// password Keychain item so it benefits from the same OS-level
    /// protections as any other saved credential.
    static func saveLoginPasswordReference() {
        // Deliberately NOT implemented here: auto-typing the user's login
        // password via keystroke injection is the highest-risk piece of
        // this whole app (a bug or bypass in your liveness check becomes
        // a full account takeover). Recommend wiring this to the
        // LocalAuthentication framework's existing password-verify flow
        // instead of storing/injecting the raw password yourself, or
        // scoping v1 to "wake + focus password field" rather than
        // "type the password for the user."
    }
}
