import Testing
@testable import EnglCore

struct InMemorySecretStoreTests {
    @Test func readsMissingAccountAsNil() {
        #expect(InMemorySecretStore().read("yandex-dictionary") == nil)
    }

    @Test func readsInitialValues() {
        let store = InMemorySecretStore(["yandex-dictionary": "key"])

        #expect(store.read("yandex-dictionary") == "key")
    }

    @Test func writesAndUpdatesValue() {
        let store = InMemorySecretStore()

        store.write("old", account: "yandex-dictionary")
        store.write("new", account: "yandex-dictionary")

        #expect(store.read("yandex-dictionary") == "new")
    }

    @Test(arguments: [nil, ""] as [String?])
    func removesValue(cleared: String?) {
        let store = InMemorySecretStore(["yandex-dictionary": "key", "other": "value"])

        store.write(cleared, account: "yandex-dictionary")

        #expect(store.read("yandex-dictionary") == nil)
        #expect(store.read("other") == "value")
    }

    @Test func worksThroughProtocol() throws {
        let store: any SecretStore = InMemorySecretStore()

        try store.write("key", account: "yandex-dictionary")

        #expect(try store.read("yandex-dictionary") == "key")
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
