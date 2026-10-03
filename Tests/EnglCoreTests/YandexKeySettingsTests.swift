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

private extension YandexKeySettings {
    func loadAndWait() async {
        load()
        await loadTask?.value
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct YandexKeySettingsTests {
    @Test func loadsStoredKey() async {
        let settings = makeSettings(secrets: FakeSecretStore([account: "stored"]))

        await settings.loadAndWait()

        #expect(settings.draft == "stored")
        #expect(settings.isLoaded)
        #expect(settings.note == nil)
        #expect(settings.canSave)
    }

    @Test func unreadableKeyIsNotDeletedByEmptySave() async {
        let secrets = FakeSecretStore([account: "stored"], failsReads: true)
        let settings = makeSettings(secrets: secrets)

        await settings.loadAndWait()
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
        await settings.loadAndWait()

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
        await settings.loadAndWait()

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
        await settings.loadAndWait()

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
        await settings.loadAndWait()

        settings.draft = " first "
        settings.save()
        settings.draft = "second"
        await settings.saveTask?.value

        #expect(secrets.value(account) == "first")
        #expect(settings.draft == "second")
    }

    @Test func savesAreStoredInOrder() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let secondArrived = DispatchSemaphore(value: 0)
        // the first write waits for the second; serialized saves never start it, hence the timeout
        let secrets = FakeSecretStore(beforeWrite: { value in
            guard value == "first" else {
                secondArrived.signal()
                return
            }
            enteredContinuation.yield()
            _ = secondArrived.wait(timeout: .now() + .milliseconds(300))
        })
        let settings = makeSettings(secrets: secrets)
        await settings.loadAndWait()

        settings.draft = "first"
        settings.save()
        for await _ in entered {
            break
        }
        settings.draft = "second"
        settings.save()
        await settings.saveTask?.value

        #expect(secrets.value(account) == "second")
        #expect(secrets.writes == 2)
        #expect(settings.note == .success("Ключ сохранён"))
    }

    @Test func reloadDuringSaveShowsSavedKey() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let secrets = FakeSecretStore([account: "old"], beforeWrite: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let settings = makeSettings(secrets: secrets)
        await settings.loadAndWait()
        settings.draft = "new"
        settings.save()
        for await _ in entered {
            break
        }

        await settings.loadAndWait()
        #expect(settings.draft == "old")
        release.signal()
        await settings.saveTask?.value

        #expect(settings.draft == "new")
        #expect(settings.note == .success("Ключ сохранён"))
    }

    @Test func editAfterReloadDuringSaveIsKept() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let secrets = FakeSecretStore([account: "old"], beforeWrite: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let settings = makeSettings(secrets: secrets)
        await settings.loadAndWait()
        settings.draft = "new"
        settings.save()
        for await _ in entered {
            break
        }

        await settings.loadAndWait()
        settings.draft = "typed"
        release.signal()
        await settings.saveTask?.value

        #expect(settings.draft == "typed")
        #expect(secrets.value(account) == "new")
    }

    @Test func failedSaveIsReported() async {
        let settings = makeSettings(secrets: FakeSecretStore(failsWrites: true))
        await settings.loadAndWait()

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

        await settings.loadAndWait()
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

    @Test func readsKeyOffMainActor() async {
        let (onMain, onMainContinuation) = AsyncStream.makeStream(of: Bool.self)
        let release = DispatchSemaphore(value: 0)
        let secrets = FakeSecretStore([account: "stored"], afterRead: { _ in
            onMainContinuation.yield(Thread.isMainThread)
            // a read on the main actor would block load() until the timeout
            _ = release.wait(timeout: .now() + .seconds(5))
        })
        let settings = makeSettings(secrets: secrets)

        settings.load()
        #expect(settings.isLoading)
        #expect(settings.draft.isEmpty)
        #expect(!settings.canSave)
        settings.save()
        release.signal()
        await settings.loadTask?.value

        var readOnMain: Bool?
        for await value in onMain {
            readOnMain = value
            break
        }
        #expect(readOnMain == false)
        #expect(!settings.isLoading)
        #expect(settings.isLoaded)
        #expect(settings.draft == "stored")
        #expect(secrets.writes == 0)
    }

    @Test func editDuringLoadIsKept() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let secrets = FakeSecretStore([account: "stored"], afterRead: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let settings = makeSettings(secrets: secrets)
        settings.load()
        for await _ in entered {
            break
        }

        settings.draft = "typed"
        release.signal()
        await settings.loadTask?.value

        #expect(settings.draft == "typed")
        #expect(settings.isLoaded)
        #expect(!settings.isLoading)
    }

    @Test func staleLoadIsDropped() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let secrets = FakeSecretStore([account: "old"], afterRead: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let settings = makeSettings(secrets: secrets)
        settings.load()
        let first = settings.loadTask
        for await _ in entered {
            break
        }

        // the second read fails before reaching afterRead, so only the first one waits
        secrets.failsReads = true
        await settings.loadAndWait()
        release.signal()
        await first?.value

        #expect(settings.draft.isEmpty)
        #expect(!settings.isLoaded)
        #expect(!settings.canSave)
        #expect(settings.note == .failure("Не удалось прочитать ключ из Связки ключей"))
    }

    @Test func saveDuringLoadWins() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let secrets = FakeSecretStore([account: "old"], afterRead: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let settings = makeSettings(secrets: secrets)
        settings.load()
        let load = settings.loadTask
        for await _ in entered {
            break
        }

        settings.draft = "new"
        settings.save()
        await settings.saveTask?.value
        #expect(!settings.isLoading)
        release.signal()
        await load?.value

        #expect(settings.draft == "new")
        #expect(settings.isLoaded)
        #expect(secrets.value(account) == "new")
        #expect(settings.note == .success("Ключ сохранён"))
    }

    @Test func checkWaitsForStoredKey() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let secrets = FakeSecretStore([account: "stored"], afterRead: { _ in
            enteredContinuation.yield()
            release.wait()
        })
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))
        let settings = makeSettings(secrets: secrets, http: http)
        #expect(settings.canCheck)
        settings.load()
        for await _ in entered {
            break
        }

        #expect(!settings.canCheck)
        settings.check()
        #expect(settings.checkTask == nil)
        #expect(!settings.isChecking)
        release.signal()
        await settings.loadTask?.value

        #expect(settings.draft == "stored")
        #expect(settings.note == nil)
        #expect(settings.canCheck)
        settings.check()
        #expect(!settings.canCheck)
        await settings.checkTask?.value
        #expect(settings.note == .success("Ключ действителен"))
        #expect(http.urls.count == 1)
        #expect(http.urls.first?.query()?.contains("key=stored") == true)
    }

    @Test func editDropsCheckInFlight() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let gate = Gate()
        let validBody = try fixture("yandex_run")
        let http = FakeHTTPClient { _ in
            enteredContinuation.yield()
            await gate.wait()
            return HTTPResponse(statusCode: 200, body: validBody)
        }
        let settings = makeSettings(http: http)
        settings.draft = "old"
        settings.check()
        let check = settings.checkTask
        for await _ in entered {
            break
        }

        settings.draft = "new"
        #expect(!settings.isChecking)
        gate.open()
        await check?.value

        #expect(!settings.isChecking)
        #expect(settings.note == nil)
    }

    @Test func saveDropsCheckInFlight() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let gate = Gate()
        let validBody = try fixture("yandex_run")
        let http = FakeHTTPClient { _ in
            enteredContinuation.yield()
            await gate.wait()
            return HTTPResponse(statusCode: 200, body: validBody)
        }
        let settings = makeSettings(http: http)
        await settings.loadAndWait()
        settings.draft = "key"
        settings.check()
        let check = settings.checkTask
        for await _ in entered {
            break
        }

        settings.save()
        #expect(!settings.isChecking)
        await settings.saveTask?.value
        gate.open()
        await check?.value

        #expect(!settings.isChecking)
        #expect(settings.note == .success("Ключ сохранён"))
    }

    @Test func editHidesCheckOutcomeOnly() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))
        let settings = makeSettings(http: http)
        await settings.loadAndWait()
        settings.draft = "key"
        settings.check()
        await settings.checkTask?.value
        #expect(settings.note == .success("Ключ действителен"))

        settings.draft = "other"
        #expect(settings.note == nil)

        settings.save()
        await settings.saveTask?.value
        settings.draft = "edited"
        #expect(settings.note == .success("Ключ сохранён"))
    }
}
