import Testing
@testable import EnglCore

private let word = Query(text: "run", source: .en, target: .ru, kind: .dictionary)
private let sentence = Query(text: "I run every day", source: .en, target: .ru, kind: .sentence)

private let card = TranslationResult.dictionary(DictionaryEntry(
    word: "run",
    transcription: "rʌn",
    groups: [PartOfSpeechGroup(partOfSpeech: "verb", translations: [Sense(text: "бежать")])]
))
private let text = TranslationResult.text(TextTranslation(source: "run", translation: "бежать"))

private struct UnexpectedError: Error {}

struct RouterTests {
    @Test func firstProviderAnswers() async throws {
        let first = FakeProvider(id: "yandex", result: card)
        let second = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [first, second])

        let routed = try await router.route(word)

        #expect(routed == RoutedResult(providerID: "yandex", result: card))
        #expect(first.calls == 1)
        #expect(second.calls == 0)
    }

    @Test(arguments: [ProviderError.notFound, .invalidKey, .notConfigured, .network])
    func fallsThroughToNextProvider(error: ProviderError) async throws {
        let first = FakeProvider(id: "yandex", error: error)
        let second = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [first, second])

        let routed = try await router.route(word)

        #expect(routed == RoutedResult(providerID: "apple", result: text))
        #expect(first.calls == 1)
        #expect(second.calls == 1)
    }

    @Test func skipsProviderThatDoesNotSupportQuery() async throws {
        let dictionary = FakeProvider(id: "yandex", kinds: [.dictionary], result: card)
        let translator = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [dictionary, translator])

        let routed = try await router.route(sentence)

        #expect(routed.providerID == "apple")
        #expect(dictionary.calls == 0)
    }

    @Test func throwsNotConfiguredWithoutSuitableProvider() async {
        let dictionary = FakeProvider(id: "yandex", kinds: [.dictionary], result: card)

        await #expect(throws: ProviderError.notConfigured) {
            try await Router(providers: [dictionary]).route(sentence)
        }
        await #expect(throws: ProviderError.notConfigured) {
            try await Router(providers: []).route(word)
        }
    }

    @Test(arguments: [
        ([ProviderError.notFound, .network], ProviderError.network),
        ([.notFound, .notConfigured], .notConfigured),
        ([.network, .invalidKey], .invalidKey),
        ([.invalidResponse, .rateLimited, .notFound], .rateLimited),
        ([.notConfigured, .languagePackMissing], .languagePackMissing),
        ([.notFound, .invalidResponse, .notConfigured], .invalidResponse),
        ([.notFound, .notFound], .notFound),
    ])
    func throwsMostUsefulErrorWhenAllFail(errors: [ProviderError], expected: ProviderError) async {
        let providers = errors.enumerated().map { index, error in
            FakeProvider(id: "provider-\(index)", error: error)
        }
        let router = Router(providers: providers)

        await #expect(throws: expected) {
            try await router.route(word)
        }
        #expect(providers.allSatisfy { $0.calls == 1 })
    }

    @Test func earliestErrorWinsTie() {
        #expect(Router.mostUseful([.network, .invalidResponse]) == .network)
        #expect(Router.mostUseful([.rateLimited, .invalidKey]) == .rateLimited)
        #expect(Router.mostUseful([]) == nil)
    }

    @Test func nonProviderErrorStopsChain() async {
        let first = FakeProvider(id: "yandex", error: UnexpectedError())
        let second = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [first, second])

        await #expect(throws: UnexpectedError.self) {
            try await router.route(word)
        }
        #expect(second.calls == 0)
    }
}

struct RouterCacheTests {
    @Test func repeatedQueryIsServedFromCache() async throws {
        let provider = FakeProvider(id: "yandex", result: card)
        let router = Router(providers: [provider])

        let first = try await router.route(word)
        let second = try await router.route(word)

        #expect(first == second)
        #expect(provider.calls == 1)
    }

    @Test func differentQueriesAreCachedSeparately() async throws {
        let provider = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [provider])

        _ = try await router.route(word)
        _ = try await router.route(sentence)
        _ = try await router.route(sentence)

        #expect(provider.calls == 2)
    }

    @Test func fallbackResultIsNotCached() async throws {
        let first = FakeProvider(id: "yandex", error: ProviderError.network)
        let second = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [first, second])

        _ = try await router.route(word)
        let routed = try await router.route(word)

        #expect(routed.providerID == "apple")
        #expect(first.calls == 2)
        #expect(second.calls == 2)
    }

    @Test func failureIsNotCached() async {
        let provider = FakeProvider(id: "yandex", error: ProviderError.network)
        let router = Router(providers: [provider])

        await #expect(throws: ProviderError.network) { try await router.route(word) }
        await #expect(throws: ProviderError.network) { try await router.route(word) }
        #expect(provider.calls == 2)
    }

    @Test func invalidateClearsCache() async throws {
        let provider = FakeProvider(id: "yandex", result: card)
        let router = Router(providers: [provider])

        _ = try await router.route(word)
        await router.invalidate()
        _ = try await router.route(word)

        #expect(provider.calls == 2)
    }

    @Test func evictsOldestEntryOverLimit() async throws {
        let provider = FakeProvider(id: "yandex") { query in
            .text(TextTranslation(source: query.text, translation: query.text.uppercased()))
        }
        let router = Router(providers: [provider], cacheLimit: 2)
        let queries = ["a", "b", "c"].map {
            Query(text: $0, source: .en, target: .ru, kind: .dictionary)
        }

        for query in queries {
            _ = try await router.route(query)
        }
        _ = try await router.route(queries[1])
        _ = try await router.route(queries[2])
        #expect(provider.calls == 3)

        _ = try await router.route(queries[0])
        #expect(provider.calls == 4)
    }

    @Test func zeroLimitDisablesCache() async throws {
        let provider = FakeProvider(id: "yandex", result: card)
        let router = Router(providers: [provider], cacheLimit: 0)

        _ = try await router.route(word)
        _ = try await router.route(word)

        #expect(provider.calls == 2)
    }

    @Test func resultStartedBeforeInvalidateIsNotCached() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let provider = FakeProvider(id: "yandex") { _ in
            enteredContinuation.yield()
            for await _ in gate {
                break
            }
            return card
        }
        let router = Router(providers: [provider])

        let pending = Task { try await router.route(word) }
        for await _ in entered {
            break
        }
        await router.invalidate()
        gateContinuation.yield()
        _ = try await pending.value

        gateContinuation.yield()
        _ = try await router.route(word)
        #expect(provider.calls == 2)
    }
}

struct RouterCancellationTests {
    @Test func cancellationErrorDoesNotFallThrough() async {
        let first = FakeProvider(id: "yandex", error: CancellationError())
        let second = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [first, second])

        await #expect(throws: CancellationError.self) {
            try await router.route(word)
        }
        #expect(second.calls == 0)
    }

    @Test func cancelledTaskStopsChain() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let first = FakeProvider(id: "yandex") { _ in
            enteredContinuation.yield()
            try await Task.sleep(for: .seconds(60))
            return card
        }
        let second = FakeProvider(id: "apple", result: text)
        let router = Router(providers: [first, second])

        let pending = Task { try await router.route(word) }
        for await _ in entered {
            break
        }
        pending.cancel()

        await #expect(throws: CancellationError.self) {
            try await pending.value
        }
        #expect(second.calls == 0)
    }

    @Test func alreadyCancelledTaskSkipsProviders() async {
        let provider = FakeProvider(id: "yandex", result: card)
        let router = Router(providers: [provider])

        let pending = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await router.route(word)
        }

        await #expect(throws: CancellationError.self) {
            try await pending.value
        }
        #expect(provider.calls == 0)
    }
}
