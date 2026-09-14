import Foundation
import Security

/// Thin wrapper over the generic-password keychain.
///
/// Everything that is a credential — subscription URLs (the path segment is the
/// bearer token), per-subscription HWIDs, and any future API token — lives here
/// rather than in `store.json`, so a file copy of Application Support does not
/// hand over the account.
enum Keychain {

    /// Service under which every Veil item is filed.
    static let service = "com.veil.client"

    @discardableResult
    static func set(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        var query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }

        query[kSecValueData as String] = data
        // The item is only needed while someone is using the Mac, and it must
        // never travel to another device via iCloud Keychain.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func get(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    static func remove(account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// True when the keychain is actually usable. An unsigned or sandboxed-away
    /// build can fail every write; callers fall back to file storage rather
    /// than silently dropping the user's subscriptions.
    static var isAvailable: Bool {
        let probe = "__veil_probe__"
        guard set(UUID().uuidString, account: probe) else { return false }
        defer { remove(account: probe) }
        return get(account: probe) != nil
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// Keychain account names used by the app, in one place so nothing collides.
enum KeychainAccount {
    /// The URL of a subscription, keyed by its stable identifier.
    static func subscriptionURL(_ id: UUID) -> String { "sub.url.\(id.uuidString)" }
    /// The HWID Veil presents to one subscription's panel.
    static func subscriptionHWID(_ id: UUID) -> String { "sub.hwid.\(id.uuidString)" }
    /// Bearer token for the local control API.
    static let apiToken = "api.token"
}
