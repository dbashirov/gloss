import Testing
@testable import EnglCore

private let word = Query(text: "run", source: .en, target: .ru, kind: .dictionary)
private let text = TranslationResult.text(TextTranslation(source: "run", translation: "бежать"))

private struct FailingSecretStore: SecretStore {
    struct Failure: Error {}

    func read(_ account: String) throws -> String? {
        throw Failure()
    }

    func write(_ value: String?, account: String) throws {
        throw Failure()
    }
}

struct YandexKeyStoreTests {
    @Test func loadsStoredKey() throws {
        let secrets = InMemorySecretStore([YandexDictionaryProvider.keyAccount: "stored"])
        let store = YandexKeyStore(secrets: secrets, router: Router(providers: []))

        #expect(try store.load() == "stored")
    }

    @Test func loadsEmptyStringWithoutKey() throws {
        let store = YandexKeyStore(secrets: InMemorySecretStore(), router: Router(providers: []))

        #expect(try store.load() == "")
    }

    @Test func savesTrimmedKey() async throws {
        let secrets = InMemorySecretStore()
        let store = YandexKeyStore(secrets: secrets, router: Router(providers: []))

        try await store.save("  new-key\n")

        #expect(secrets.read(YandexDictionaryProvider.keyAccount) == "new-key")
    }

    @Test(arguments: ["", "  \n"])
    func blankKeyRemovesStoredKey(key: String) async throws {
        let secrets = InMemorySecretStore([YandexDictionaryProvider.keyAccount: "old"])
        let store = YandexKeyStore(secrets: secrets, router: Router(providers: []))

        try await store.save(key)

        #expect(secrets.read(YandexDictionaryProvider.keyAccount) == nil)
    }

    @Test func savingInvalidatesRouterCache() async throws {
        let provider = FakeProvider(id: "yandex", result: text)
        let router = Router(providers: [provider])
        let store = YandexKeyStore(secrets: InMemorySecretStore(), router: router)
        _ = try await router.route(word)
        _ = try await router.route(word)
        #expect(provider.calls == 1)

        try await store.save("new-key")
        _ = try await router.route(word)

        #expect(provider.calls == 2)
    }

    @Test func failedSaveKeepsRouterCache() async throws {
        let provider = FakeProvider(id: "yandex", result: text)
        let router = Router(providers: [provider])
        let store = YandexKeyStore(secrets: FailingSecretStore(), router: router)
        _ = try await router.route(word)

        await #expect(throws: FailingSecretStore.Failure.self) {
            try await store.save("new-key")
        }
        _ = try await router.route(word)

        #expect(provider.calls == 1)
    }

    @Test func loadReportsUnreadableKey() {
        let store = YandexKeyStore(secrets: FailingSecretStore(), router: Router(providers: []))

        #expect(throws: FailingSecretStore.Failure.self) {
            try store.load()
        }
    }
}
