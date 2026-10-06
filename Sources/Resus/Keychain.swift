import Foundation
import Security
import LocalAuthentication
import ResusCore

struct Keychain: Sendable {
    let service: String
    func read(_ provider: Provider) throws -> String {
        var query = base(provider)
        query[kSecReturnData as String] = true
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw ResusError.invalid("Resus could not read the API key from Keychain.")
        }
        return key
    }
    func save(_ key: String, provider: Provider) throws {
        var query = base(provider)
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        if key.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw ResusError.invalid("Resus could not remove the API key.") }
            return
        }
        let changes: [String: Any] = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(key.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ResusError.invalid("Resus could not save the API key to Keychain.") }
        } else if status != errSecSuccess { throw ResusError.invalid("Resus could not update the API key in Keychain.") }
    }
    private func base(_ provider: Provider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: provider.rawValue]
    }
}
