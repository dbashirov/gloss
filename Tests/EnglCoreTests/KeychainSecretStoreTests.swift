import Foundation
import Security
import Testing
@testable import EnglCore

private let account = YandexDictionaryProvider.keyAccount

/// Returns a store with a service unique to this run so tests never touch real app items.
private func makeStore() -> KeychainSecretStore {
    KeychainSecretStore(service: "com.dbashirov.engl.tests.\(UUID.v7().uuidString)")
}

private func removeAllItems(of store: KeychainSecretStore) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: store.service,
    ]
    SecItemDelete(query as CFDictionary)
}

@Suite(.tags(.keychain))
struct KeychainSecretStoreTests {
    @Test func readsMissingAccountAsNil() throws {
        let store = makeStore()
        defer { removeAllItems(of: store) }

        #expect(try store.read(account) == nil)
    }

    @Test func writesAndReadsValue() throws {
        let store = makeStore()
        defer { removeAllItems(of: store) }

        try store.write("dict.1.key-ключ", account: account)

        #expect(try store.read(account) == "dict.1.key-ключ")
    }

    @Test func updatesExistingValue() throws {
        let store = makeStore()
        defer { removeAllItems(of: store) }

        try store.write("old", account: account)
        try store.write("new", account: account)

        #expect(try store.read(account) == "new")
    }

    @Test(arguments: [nil, ""] as [String?])
    func removesValue(cleared: String?) throws {
        let store = makeStore()
        defer { removeAllItems(of: store) }

        try store.write("key", account: account)
        try store.write(cleared, account: account)

        #expect(try store.read(account) == nil)
    }

    @Test func removingMissingValueSucceeds() throws {
        let store = makeStore()
        defer { removeAllItems(of: store) }

        try store.write(nil, account: account)

        #expect(try store.read(account) == nil)
    }

    @Test func keepsAccountsSeparate() throws {
        let store = makeStore()
        defer { removeAllItems(of: store) }

        try store.write("first", account: "one")
        try store.write("second", account: "two")
        try store.write(nil, account: "one")

        #expect(try store.read("one") == nil)
        #expect(try store.read("two") == "second")
    }

    @Test func keepsServicesSeparate() throws {
        let store = makeStore()
        let other = makeStore()
        defer {
            removeAllItems(of: store)
            removeAllItems(of: other)
        }

        try store.write("mine", account: account)

        #expect(try other.read(account) == nil)
    }

    @Test func rejectsValueThatIsNotUTF8() throws {
        let store = makeStore()
        defer { removeAllItems(of: store) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: store.service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data([0xFF, 0xFE, 0xFD]),
        ]
        #expect(SecItemAdd(query as CFDictionary, nil) == errSecSuccess)

        #expect(throws: KeychainError.invalidData) {
            try store.read(account)
        }
    }

    @Test func usesAppServiceByDefault() {
        #expect(KeychainSecretStore().service == "com.dbashirov.engl")
    }

    @Test func describesStatus() {
        let description = KeychainError.unexpectedStatus(errSecAuthFailed).localizedDescription

        #expect(description.hasPrefix("Keychain error \(errSecAuthFailed): "))
        #expect(!description.hasSuffix(": "))
    }
}
