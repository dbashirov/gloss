import Foundation
import Security

/// KeychainError reports a failed Keychain call.
public enum KeychainError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidData
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
            return "Keychain error \(status): \(message)"
        case .invalidData:
            return "Keychain item does not contain a UTF-8 string"
        }
    }
}

/// KeychainSecretStore keeps secrets as generic passwords in the user's keychain.
public struct KeychainSecretStore: SecretStore {
    public static let defaultService = "com.dbashirov.engl"

    public let service: String

    public init(service: String = defaultService) {
        self.service = service
    }

    public func read(_ account: String) throws -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func write(_ value: String?, account: String) throws {
        guard let value, !value.isEmpty else {
            try delete(account)
            return
        }
        let data = Data(value.utf8)
        let query = baseQuery(account)
        let attributes = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }
        guard status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
        let addStatus = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private func delete(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
