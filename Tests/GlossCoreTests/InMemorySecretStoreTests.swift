import Testing
@testable import GlossCore

private let account = YandexDictionaryProvider.keyAccount

struct InMemorySecretStoreTests {
    @Test func readsMissingAccountAsNil() {
        #expect(InMemorySecretStore().read(account) == nil)
    }

    @Test func readsInitialValues() {
        let store = InMemorySecretStore([account: "key"])

        #expect(store.read(account) == "key")
    }

    @Test func writesAndUpdatesValue() {
        let store = InMemorySecretStore()

        store.write("old", account: account)
        store.write("new", account: account)

        #expect(store.read(account) == "new")
    }

    @Test(arguments: [nil, ""] as [String?])
    func removesValue(cleared: String?) {
        let store = InMemorySecretStore([account: "key", "other": "value"])

        store.write(cleared, account: account)

        #expect(store.read(account) == nil)
        #expect(store.read("other") == "value")
    }

    @Test func worksThroughProtocol() throws {
        let store: any SecretStore = InMemorySecretStore()

        try store.write("key", account: account)

        #expect(try store.read(account) == "key")
    }

    @Test func handlesConcurrentWrites() async {
        let store = InMemorySecretStore()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask { store.write("\(index)", account: "account-\(index)") }
            }
        }

        #expect((0..<100).allSatisfy { store.read("account-\($0)") == "\($0)" })
    }
}
