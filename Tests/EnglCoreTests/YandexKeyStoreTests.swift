import Testing
@testable import EnglCore

private let account = YandexDictionaryProvider.keyAccount

struct YandexKeyStoreTests {
    @Test func loadsStoredKey() async throws {
        let secrets = FakeSecretStore([account: "stored"])
        let store = YandexKeyStore(secrets: secrets, router: Router(providers: []))

        #expect(try await store.load() == "stored")
    }

    @Test func loadsEmptyStringWithoutKey() async throws {
        let store = YandexKeyStore(secrets: FakeSecretStore(), router: Router(providers: []))

        #expect(try await store.load() == "")
    }

    @Test func savesTrimmedKey() async throws {
        let secrets = FakeSecretStore()
        let store = YandexKeyStore(secrets: secrets, router: Router(providers: []))

        let saved = try await store.save("  new-key\n")

        #expect(saved == "new-key")
        #expect(secrets.value(account) == "new-key")
    }

    @Test(arguments: ["", "  \n"])
    func blankKeyRemovesStoredKey(key: String) async throws {
        let secrets = FakeSecretStore([account: "old"])
        let store = YandexKeyStore(secrets: secrets, router: Router(providers: []))

        let saved = try await store.save(key)

        #expect(saved.isEmpty)
        #expect(secrets.value(account) == nil)
    }

    @Test func savingInvalidatesRouterCache() async throws {
        let provider = FakeProvider(id: "yandex", result: runText)
        let router = Router(providers: [provider])
        let store = YandexKeyStore(secrets: FakeSecretStore(), router: router)
        _ = try await router.route(runQuery)
        _ = try await router.route(runQuery)
        #expect(provider.calls == 1)

        try await store.save("new-key")
        _ = try await router.route(runQuery)

        #expect(provider.calls == 2)
    }

    @Test func failedSaveKeepsRouterCache() async throws {
        let provider = FakeProvider(id: "yandex", result: runText)
        let router = Router(providers: [provider])
        let store = YandexKeyStore(secrets: FakeSecretStore.broken(), router: router)
        _ = try await router.route(runQuery)

        await #expect(throws: FakeSecretStore.Failure.self) {
            try await store.save("new-key")
        }
        _ = try await router.route(runQuery)

        #expect(provider.calls == 1)
    }

    @Test func loadReportsUnreadableKey() async {
        let store = YandexKeyStore(secrets: FakeSecretStore.broken(), router: Router(providers: []))

        await #expect(throws: FakeSecretStore.Failure.self) {
            try await store.load()
        }
    }
}
