import Security
import Foundation

/// Stores enrolled face profiles and credentials in the macOS Keychain.
/// Everything stays on-device; nothing is ever transmitted.
enum KeychainStore {
    private static let service = "com.lookt.embeddings"
    private static let legacyAccount = "enrolled-faces"
    private static let profilesAccount = "enrolled-profiles"
    private static let passwordService = "com.lookt.loginpassword"
    private static let passwordAccount = "mac-login-credential"

    // MARK: - Face Profiles Management

    static func saveProfiles(_ profiles: [FaceProfile]) -> Bool {
        guard let data = try? JSONEncoder().encode(profiles) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profilesAccount
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func loadProfiles() -> [FaceProfile] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profilesAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
           let profiles = try? JSONDecoder().decode([FaceProfile].self, from: data) {
            return profiles
        }

        // Migrate legacy single enrollment if present
        let legacy = loadLegacyEmbeddings()
        if !legacy.isEmpty {
            let migratedProfile = FaceProfile(
                name: "Primary Face",
                style: .defaultFace,
                dateEnrolled: Date(),
                embeddings: legacy
            )
            _ = saveProfiles([migratedProfile])
            clearLegacyEnrollment()
            return [migratedProfile]
        }

        return []
    }

    static func addProfile(_ profile: FaceProfile) -> Bool {
        var profiles = loadProfiles()
        profiles.append(profile)
        return saveProfiles(profiles)
    }

    static func deleteProfile(id: UUID) -> Bool {
        var profiles = loadProfiles()
        profiles.removeAll { $0.id == id }
        return saveProfiles(profiles)
    }

    static func hasProfiles() -> Bool {
        !loadProfiles().isEmpty
    }

    static func allEmbeddings() -> [FaceEmbedding] {
        loadProfiles().flatMap(\.embeddings)
    }

    // MARK: - Legacy Embedding Support

    static func saveEmbeddings(_ embeddings: [FaceEmbedding]) -> Bool {
        let defaultProfile = FaceProfile(
            name: "Primary Face",
            style: .defaultFace,
            dateEnrolled: Date(),
            embeddings: embeddings
        )
        return saveProfiles([defaultProfile])
    }

    static func loadEmbeddings() -> [FaceEmbedding] {
        allEmbeddings()
    }

    static func hasEnrollment() -> Bool {
        hasProfiles()
    }

    static func clearEnrollment() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profilesAccount
        ]
        SecItemDelete(query as CFDictionary)
        clearLegacyEnrollment()
    }

    private static func loadLegacyEmbeddings() -> [FaceEmbedding] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount,
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

    private static func clearLegacyEnrollment() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Login Password (for Auto-Unlock)

    static func saveLoginPassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        deleteLoginPassword()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: passwordService,
            kSecAttrAccount as String: passwordAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func loadLoginPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: passwordService,
            kSecAttrAccount as String: passwordAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    static func deleteLoginPassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: passwordService,
            kSecAttrAccount as String: passwordAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hasLoginPassword() -> Bool {
        loadLoginPassword() != nil
    }
}
