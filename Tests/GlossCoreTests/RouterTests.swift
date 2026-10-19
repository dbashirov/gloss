import Foundation
import Testing
@testable import GlossCore

struct RouterTests {
    @Test func firstProviderAnswers() async throws {
        let first = FakeProvider(id: "yandex", result: runCard)
        let second = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [first, second])

        let routed = try await router.route(runQuery)

        #expect(routed == RoutedResult(providerID: "yandex", result: runCard))
        #expect(first.calls == 1)
        #expect(second.calls == 0)
    }

    @Test(arguments: [ProviderError.notFound, .invalidKey, .notConfigured, .network])
    func fallsThroughToNextProvider(error: ProviderError) async throws {
        let first = FakeProvider(id: "yandex", error: error)
        let second = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [first, second])

        let routed = try await router.route(runQuery)

        #expect(routed == RoutedResult(providerID: "apple", result: runText, fallbackError: error))
        #expect(first.calls == 1)
        #expect(second.calls == 1)
    }

    @Test func reportsMostUsefulErrorOfSkippedProviders() async throws {
        let providers = [
            FakeProvider(id: "yandex", error: ProviderError.notFound),
            FakeProvider(id: "claude", error: ProviderError.rateLimited),
            FakeProvider(id: "apple", result: runText),
        ]

        let routed = try await Router(providers: providers).route(runQuery)

        #expect(routed.fallbackError == .rateLimited)
    }

    @Test func firstAnswerHasNoFallbackError() async throws {
        let routed = try await Router(providers: [FakeProvider(id: "yandex", result: runCard)])
            .route(runQuery)

        #expect(routed.fallbackError == nil)
    }

    @Test func skipsProviderThatDoesNotSupportQuery() async throws {
        let dictionary = FakeProvider(id: "yandex", kinds: [.dictionary], result: runCard)
        let translator = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [dictionary, translator])

        let routed = try await router.route(sentenceQuery)

        #expect(routed.providerID == "apple")
        #expect(dictionary.calls == 0)
    }

    @Test func throwsNotConfiguredWithoutSuitableProvider() async {
        let dictionary = FakeProvider(id: "yandex", kinds: [.dictionary], result: runCard)

        await #expect(throws: ProviderError.notConfigured) {
            try await Router(providers: [dictionary]).route(sentenceQuery)
        }
        await #expect(throws: ProviderError.notConfigured) {
            try await Router(providers: []).route(runQuery)
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
            try await router.route(runQuery)
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
        let second = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [first, second])

        await #expect(throws: UnexpectedError.self) {
            try await router.route(runQuery)
        }
        #expect(second.calls == 0)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct RouterCacheTests {
    @Test func repeatedQueryIsServedFromCache() async throws {
        let provider = FakeProvider(id: "yandex", result: runCard)
        let router = Router(providers: [provider])

        let first = try await router.route(runQuery)
        let second = try await router.route(runQuery)

        #expect(first == second)
        #expect(provider.calls == 1)
    }

    @Test func differentQueriesAreCachedSeparately() async throws {
        let provider = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [provider])

        _ = try await router.route(runQuery)
        _ = try await router.route(sentenceQuery)
        _ = try await router.route(sentenceQuery)

        #expect(provider.calls == 2)
    }

    @Test func fallbackResultIsNotCached() async throws {
        let first = FakeProvider(id: "yandex", error: ProviderError.network)
        let second = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [first, second])

        _ = try await router.route(runQuery)
        let routed = try await router.route(runQuery)

        #expect(routed.providerID == "apple")
        #expect(first.calls == 2)
        #expect(second.calls == 2)
    }

    @Test func failureIsNotCached() async {
        let provider = FakeProvider(id: "yandex", error: ProviderError.network)
        let router = Router(providers: [provider])

        await #expect(throws: ProviderError.network) { try await router.route(runQuery) }
        await #expect(throws: ProviderError.network) { try await router.route(runQuery) }
        #expect(provider.calls == 2)
    }

    @Test func invalidateClearsCache() async throws {
        let provider = FakeProvider(id: "yandex", result: runCard)
        let router = Router(providers: [provider])

        _ = try await router.route(runQuery)
        await router.invalidate()
        _ = try await router.route(runQuery)
        #expect(provider.calls == 2)

        _ = try await router.route(runQuery)
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

    @Test func resultStartedBeforeInvalidateIsNotCached() async throws {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let (gate, gateContinuation) = AsyncStream.makeStream(of: Void.self)
        let provider = FakeProvider(id: "yandex") { _ in
            enteredContinuation.yield()
            for await _ in gate {
                break
            }
            return runCard
        }
        let router = Router(providers: [provider])

        let pending = Task { try await router.route(runQuery) }
        for await _ in entered {
            break
        }
        await router.invalidate()
        gateContinuation.yield()
        _ = try await pending.value

        gateContinuation.yield()
        _ = try await router.route(runQuery)
        #expect(provider.calls == 2)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct RouterCancellationTests {
    @Test func cancellationErrorDoesNotFallThrough() async {
        let first = FakeProvider(id: "yandex", error: CancellationError())
        let second = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [first, second])

        await #expect(throws: CancellationError.self) {
            try await router.route(runQuery)
        }
        #expect(second.calls == 0)
    }

    @Test func cancelledTaskStopsChain() async {
        let (entered, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let first = FakeProvider(id: "yandex") { _ in
            enteredContinuation.yield()
            try await Task.sleep(for: .seconds(60))
            return runCard
        }
        let second = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [first, second])

        let pending = Task { try await router.route(runQuery) }
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
        let provider = FakeProvider(id: "yandex", result: runCard)
        let router = Router(providers: [provider])

        let pending = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await router.route(runQuery)
        }

        await #expect(throws: CancellationError.self) {
            try await pending.value
        }
        #expect(provider.calls == 0)
    }

    @Test func cancelledTaskStopsChainAfterProviderError() async {
        let first = FakeProvider(id: "yandex") { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            throw ProviderError.network
        }
        let second = FakeProvider(id: "apple", result: runText)
        let router = Router(providers: [first, second])

        let pending = Task { try await router.route(runQuery) }

        await #expect(throws: CancellationError.self) {
            try await pending.value
        }
        #expect(first.calls == 1)
        #expect(second.calls == 0)
    }
}

/// RouterIntegrationTests run the chain with the real providers over fake transports.
struct RouterIntegrationTests {
    private func makeRouter(
        http: FakeHTTPClient,
        key: String?,
        translator: FakeTextTranslator
    ) -> Router {
        let values = key.map { [YandexDictionaryProvider.keyAccount: $0] } ?? [:]
        let secrets = FakeSecretStore(values)
        return Router(providers: [
            YandexDictionaryProvider(http: http, secrets: secrets),
            AppleTranslationProvider(translator: translator),
        ])
    }

    @Test func missingKeyAndPackReportPack() async {
        let http = FakeHTTPClient(json: "{}")
        let translator = FakeTextTranslator(status: .supported, translation: "")
        let router = makeRouter(http: http, key: nil, translator: translator)

        await #expect(throws: ProviderError.languagePackMissing) {
            try await router.route(runQuery)
        }
        #expect(http.urls.isEmpty)
    }

    @Test func invalidKeyFallsBackToAppleWithNotice() async throws {
        let http = FakeHTTPClient(status: 401, body: try fixture("yandex_error_401"))
        let translator = FakeTextTranslator(translation: "бежать")
        let router = makeRouter(http: http, key: "bad-key", translator: translator)

        let routed = try await router.route(runQuery)

        #expect(routed == RoutedResult(
            providerID: AppleTranslationProvider.providerID,
            result: runText,
            fallbackError: .invalidKey
        ))
        #expect(routed.fallbackNotice == .invalidKey)
    }

    @Test func cancelledRequestStopsChain() async {
        let http = FakeHTTPClient(error: URLError(.cancelled))
        let translator = FakeTextTranslator(translation: "бежать")
        let router = makeRouter(http: http, key: "key", translator: translator)

        await #expect(throws: CancellationError.self) {
            try await router.route(runQuery)
        }
        #expect(translator.texts.isEmpty)
    }
}
