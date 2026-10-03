import Foundation
import Testing
@testable import EnglCore

private let account = YandexDictionaryProvider.keyAccount

@MainActor
private func makeSettings(
    secrets: FakeSecretStore = FakeSecretStore(),
    http: FakeHTTPClient = FakeHTTPClient(json: "{}")
) -> YandexKeySettings {
    YandexKeySettings(
        store: YandexKeyStore(secrets: secrets, router: Router(providers: [])),
        keyCheck: YandexKeyCheck(http: http)
    )
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct YandexKeySettingsTests {
    @Test func loadsStoredKey() {
        let settings = makeSettings(secrets: FakeSecretStore([account: "stored"]))

        settings.load()

        #expect(settings.draft == "stored")
        #expect(settings.isLoaded)
        #expect(settings.note == nil)
        #expect(settings.canSave)
    }

    @Test func unreadableKeyIsNotDeletedByEmptySave() async {
        let secrets = FakeSecretStore([account: "stored"], failsReads: true)
        let settings = makeSettings(secrets: secrets)

        settings.load()
        settings.save()
        await settings.saveTask?.value

        #expect(settings.draft.isEmpty)
        #expect(!settings.isLoaded)
        #expect(!settings.canSave)
        #expect(settings.note == .failure("Не удалось прочитать ключ из Связки ключей"))
        #expect(secrets.writes == 0)
        #expect(secrets.value(account) == "stored")
    }

    @Test func newKeyCanBeSavedOverUnreadableOne() async {
        let secrets = FakeSecretStore([account: "stored"], failsReads: true)
        let settings = makeSettings(secrets: secrets)
        settings.load()

        settings.draft = "new-key"
        settings.save()
        await settings.saveTask?.value

        #expect(secrets.value(account) == "new-key")
        #expect(settings.isLoaded)
        #expect(settings.note == .success("Ключ сохранён"))
    }

    @Test func savesTrimmedKey() async {
        let secrets = FakeSecretStore()
        let settings = makeSettings(secrets: secrets)
        settings.load()

        settings.draft = "  new-key\n"
        settings.save()
        await settings.saveTask?.value

        #expect(settings.draft == "new-key")
        #expect(secrets.value(account) == "new-key")
        #expect(settings.note == .success("Ключ сохранён"))
    }

    @Test func emptyDraftRemovesKey() async {
        let secrets = FakeSecretStore([account: "stored"])
        let settings = makeSettings(secrets: secrets)
        settings.load()

        settings.draft = " "
        settings.save()
        await settings.saveTask?.value

        #expect(secrets.value(account) == nil)
        #expect(settings.draft.isEmpty)
        #expect(settings.note == .success("Ключ удалён"))
    }

    @Test func editDuringSaveIsKept() async {
        let secrets = FakeSecretStore()
        let settings = makeSettings(secrets: secrets)
        settings.load()

        settings.draft = " first "
        settings.save()
        settings.draft = "second"
        await settings.saveTask?.value

        #expect(secrets.value(account) == "first")
        #expect(settings.draft == "second")
    }

    @Test func failedSaveIsReported() async {
        let settings = makeSettings(secrets: FakeSecretStore(failsWrites: true))
        settings.load()

        settings.draft = "new-key"
        settings.save()
        await settings.saveTask?.value

        #expect(settings.note == .failure("Не удалось сохранить ключ в Связку ключей"))
        #expect(settings.draft == "new-key")
    }

    @Test func checkAcceptsValidKeyWithoutSaving() async throws {
        let secrets = FakeSecretStore()
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))
        let settings = makeSettings(secrets: secrets, http: http)

        settings.draft = "valid-key"
        settings.check()
        #expect(settings.isChecking)
        await settings.checkTask?.value

        #expect(!settings.isChecking)
        #expect(settings.note == .success("Ключ действителен"))
        #expect(secrets.writes == 0)
    }

    @Test func checkReportsInvalidKey() async throws {
        let http = FakeHTTPClient(status: 401, body: try fixture("yandex_error_401"))
        let settings = makeSettings(http: http)

        settings.draft = "bad-key"
        settings.check()
        await settings.checkTask?.value

        #expect(!settings.isChecking)
        #expect(settings.note == .failure(ProviderError.invalidKey.message))
    }

    @Test func cancellationNobodyAskedForEndsCheck() async {
        let settings = makeSettings(http: FakeHTTPClient(error: URLError(.cancelled)))

        settings.draft = "key"
        settings.check()
        await settings.checkTask?.value

        #expect(!settings.isChecking)
        #expect(settings.note == .failure(ProviderError.invalidResponse.message))
    }

    @Test func reloadDropsCheckInFlight() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let gate = Gate()
        let http = FakeHTTPClient { _ in
            enteredContinuation.yield()
            await gate.wait()
            return HTTPResponse(statusCode: 401, body: Data())
        }
        let settings = makeSettings(http: http)
        settings.draft = "key"
        settings.check()
        let check = settings.checkTask
        for await _ in entered {
            break
        }

        settings.load()
        gate.open()
        await check?.value

        #expect(!settings.isChecking)
        #expect(settings.note == nil)
    }

    @Test func newerCheckWins() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let gate = Gate()
        let validBody = try fixture("yandex_run")
        let http = FakeHTTPClient { url in
            guard url.query()?.contains("key=old") == true else {
                return HTTPResponse(statusCode: 200, body: validBody)
            }
            enteredContinuation.yield()
            await gate.wait()
            return HTTPResponse(statusCode: 401, body: Data())
        }
        let settings = makeSettings(http: http)
        settings.draft = "old"
        settings.check()
        let first = settings.checkTask
        for await _ in entered {
            break
        }

        settings.draft = "new"
        settings.check()
        await settings.checkTask?.value
        gate.open()
        await first?.value

        #expect(settings.note == .success("Ключ действителен"))
        #expect(!settings.isChecking)
    }
}
