import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    /// Current service name for wallet secrets under `com.zeroa.wallet`.
    private let service = "com.zeroa.wallet"
    /// Legacy service names from earlier bundle IDs — read + migrate on first access.
    private let legacyServices = ["com.tls.Zeroa", "com.yourname.PAAI"]

    private func query(account: String?, serviceName: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        if let account {
            q[kSecAttrAccount as String] = account
        }
        return q
    }

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        var q = query(account: key, serviceName: service)
        SecItemDelete(q as CFDictionary)
        q[kSecValueData as String] = data
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    func read(key: String) -> String? {
        for serviceName in [service] + legacyServices {
            var q = query(account: key, serviceName: serviceName)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var dataTypeRef: AnyObject?
            let status = SecItemCopyMatching(q as CFDictionary, &dataTypeRef)
            if status == errSecSuccess, let data = dataTypeRef as? Data,
               let value = String(data: data, encoding: .utf8) {
                if serviceName != service {
                    _ = save(key: key, value: value)
                }
                return value
            }
        }
        return nil
    }

    func delete(key: String) -> Bool {
        var ok = false
        for serviceName in [service] + legacyServices {
            let status = SecItemDelete(query(account: key, serviceName: serviceName) as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound { ok = true }
        }
        return ok
    }

    func deleteAll() -> Bool {
        var ok = false
        for serviceName in [service] + legacyServices {
            let status = SecItemDelete(query(account: nil, serviceName: serviceName) as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound { ok = true }
        }
        return ok
    }
}
