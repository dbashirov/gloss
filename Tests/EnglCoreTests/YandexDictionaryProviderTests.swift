import Foundation
import Testing
@testable import EnglCore

private let run = Query(text: "run", source: .en, target: .ru, kind: .dictionary)
private let bezhat = Query(text: "бежать", source: .ru, target: .en, kind: .dictionary)
private let sentence = Query(text: "I run every day", source: .en, target: .ru, kind: .sentence)

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func makeProvider(
    _ http: FakeHTTPClient,
    key: String? = "test-key"
) -> YandexDictionaryProvider {
    let secrets = InMemorySecretStore()
    secrets.write(key, account: YandexDictionaryProvider.keyAccount)
    return YandexDictionaryProvider(http: http, secrets: secrets)
}

private func entry(of result: TranslationResult) throws -> DictionaryEntry {
    guard case .dictionary(let entry) = result else {
        Issue.record("expected a dictionary card, got \(result)")
        throw ProviderError.invalidResponse
    }
    return entry
}

private struct BrokenSecretStore: SecretStore {
    struct Failure: Error {}

    func read(_ account: String) throws -> String? {
        throw Failure()
    }

    func write(_ value: String?, account: String) throws {
        throw Failure()
    }
}

struct YandexDictionaryProviderParsingTests {
    @Test func parsesEnglishWordCard() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))

        let card = try entry(of: try await makeProvider(http).translate(run))

        #expect(card.word == "run")
        #expect(card.transcription == "rʌn")
        #expect(card.groups.map(\.partOfSpeech) == ["verb", "noun"])
        #expect(card.groups[0].translations.map(\.text) == ["бежать", "управлять"])
        #expect(card.groups[1].translations.map(\.text) == ["пробег"])
    }

    @Test func parsesSynonymsMeaningsAndExamples() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))

        let card = try entry(of: try await makeProvider(http).translate(run))

        let first = card.groups[0].translations[0]
        #expect(first == Sense(
            text: "бежать",
            synonyms: ["бегать", "побежать"],
            meanings: ["flee", "go"],
            examples: [
                Example(source: "run away", translation: "убегать"),
                Example(source: "run fast", translation: "быстро бежать, быстро бегать"),
            ]
        ))
        let manage = card.groups[0].translations[1]
        #expect(manage.synonyms.isEmpty)
        #expect(manage.meanings == ["manage"])
        #expect(card.groups[1].translations[0].examples.isEmpty)
    }

    @Test func parsesRussianWordWithoutTranscription() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_ru_word"))

        let card = try entry(of: try await makeProvider(http).translate(bezhat))

        #expect(card == DictionaryEntry(
            word: "бежать",
            transcription: nil,
            groups: [PartOfSpeechGroup(partOfSpeech: "глагол", translations: [
                Sense(
                    text: "run",
                    synonyms: ["flee"],
                    meanings: ["бегать", "убегать"],
                    examples: [Example(source: "бежать быстро", translation: "run fast")]
                ),
                Sense(text: "escape"),
            ])]
        ))
    }

    @Test func usesBaseFormFromResponse() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))
        let running = Query(text: "running", source: .en, target: .ru, kind: .dictionary)

        let card = try entry(of: try await makeProvider(http).translate(running))

        #expect(card.word == "run")
    }

    @Test func skipsEmptyValuesAndTakesFirstTranscription() async throws {
        let http = FakeHTTPClient(json: """
        {"def": [
          {"text": "", "pos": "noun", "tr": []},
          {"text": "set", "pos": "", "tr": [
            {"text": "набор", "syn": [{"text": " "}], "ex": [{"text": "a set", "tr": []}]},
            {"text": "  "}
          ]},
          {"text": "set", "pos": "verb", "ts": "set", "tr": [{"text": "ставить"}]}
        ]}
        """)

        let card = try entry(of: try await makeProvider(http).translate(run))

        #expect(card == DictionaryEntry(
            word: "set",
            transcription: "set",
            groups: [
                PartOfSpeechGroup(partOfSpeech: nil, translations: [
                    Sense(text: "набор", examples: [Example(source: "a set", translation: nil)]),
                ]),
                PartOfSpeechGroup(partOfSpeech: "verb", translations: [Sense(text: "ставить")]),
            ]
        ))
    }
}

struct YandexDictionaryProviderErrorTests {
    @Test func supportsOnlyDictionaryQueries() {
        let provider = makeProvider(FakeHTTPClient(json: "{}"))

        #expect(provider.id == "yandex")
        #expect(provider.supports(run))
        #expect(!provider.supports(sentence))
    }

    @Test(arguments: [nil, "", "  \n"] as [String?])
    func throwsNotConfiguredWithoutKey(key: String?) async {
        let http = FakeHTTPClient(json: "{}")

        await #expect(throws: ProviderError.notConfigured) {
            try await makeProvider(http, key: key).translate(run)
        }
        #expect(http.urls.isEmpty)
    }

    @Test func throwsNotConfiguredWhenKeyIsUnreadable() async {
        let http = FakeHTTPClient(json: "{}")
        let provider = YandexDictionaryProvider(http: http, secrets: BrokenSecretStore())

        await #expect(throws: ProviderError.notConfigured) {
            try await provider.translate(run)
        }
        #expect(http.urls.isEmpty)
    }

    @Test func throwsNotFoundForEmptyDefinitions() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_empty"))

        await #expect(throws: ProviderError.notFound) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test func throwsNotFoundWhenDefinitionsHaveNoTranslations() async {
        let http = FakeHTTPClient(json: #"{"def": [{"text": "run", "pos": "verb", "tr": []}]}"#)

        await #expect(throws: ProviderError.notFound) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test(arguments: [
        (401, ProviderError.invalidKey),
        (402, .invalidKey),
        (403, .rateLimited),
        (413, .notFound),
        (501, .notFound),
        (500, .invalidResponse),
        (503, .invalidResponse),
        (400, .invalidResponse),
    ])
    func mapsHTTPStatus(status: Int, expected: ProviderError) async throws {
        let http = FakeHTTPClient(status: status, body: try fixture("yandex_error_401"))

        await #expect(throws: expected) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test func mapsErrorCodeInSuccessfulResponse() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_error_401"))

        await #expect(throws: ProviderError.invalidKey) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test(arguments: ["", "not json", #"{"def": "run"}"#, "[]", #"{"code": 200}"#])
    func throwsInvalidResponseForBrokenJSON(body: String) async {
        let http = FakeHTTPClient(json: body)

        await #expect(throws: ProviderError.invalidResponse) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test(arguments: [
        URLError.Code.timedOut,
        .notConnectedToInternet,
        .networkConnectionLost,
        .cannotFindHost,
        .badServerResponse,
    ])
    func mapsTransportErrorsToNetwork(code: URLError.Code) async {
        let http = FakeHTTPClient(error: URLError(code))

        await #expect(throws: ProviderError.network) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test func mapsUnknownErrorToNetwork() async {
        struct Unknown: Error {}
        let http = FakeHTTPClient(error: Unknown())

        await #expect(throws: ProviderError.network) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test func mapsCancelledRequestToCancellationError() async {
        let http = FakeHTTPClient(error: URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test func throwsCancellationWhenTaskIsCancelledDuringRequest() async {
        let http = FakeHTTPClient { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            throw URLError(.timedOut)
        }

        await #expect(throws: CancellationError.self) {
            try await makeProvider(http).translate(run)
        }
    }

    @Test func cancelsInFlightRequest() async {
        let http = FakeHTTPClient { _ in
            try await Task.sleep(for: .seconds(60))
            return HTTPResponse(statusCode: 200, body: Data())
        }
        let provider = makeProvider(http)
        let task = Task { try await provider.translate(run) }

        while http.urls.isEmpty {
            await Task.yield()
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}

struct YandexLookupURLTests {
    private func items(_ url: URL) throws -> [String: String] {
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(components.queryItems)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func buildsLookupRequest() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))

        _ = try await makeProvider(http, key: " secret-key\n").translate(run)

        let url = try #require(http.urls.first)
        #expect(url.scheme == "https")
        #expect(url.host() == "dictionary.yandex.net")
        #expect(url.path() == "/api/v1/dicservice.json/lookup")
        #expect(try items(url) == [
            "key": "secret-key",
            "lang": "en-ru",
            "text": "run",
            "ui": "ru",
            "flags": "4",
        ])
    }

    @Test func usesRussianToEnglishDirection() throws {
        let url = YandexDictionaryProvider.lookupURL(for: bezhat, key: "key")

        #expect(try items(url)["lang"] == "ru-en")
        #expect(try items(url)["text"] == "бежать")
        #expect(url.absoluteString.contains("text=%D0%B1%D0%B5%D0%B6%D0%B0%D1%82%D1%8C"))
    }

    @Test(arguments: [
        ("rock & roll", "text=rock%20%26%20roll&"),
        ("C++", "text=C%2B%2B&"),
        ("a=b#c?", "text=a%3Db%23c?&"),
        ("well-known", "text=well-known&"),
    ])
    func escapesText(text: String, encoded: String) throws {
        let query = Query(text: text, source: .en, target: .ru, kind: .dictionary)

        let url = YandexDictionaryProvider.lookupURL(for: query, key: "key")

        #expect(url.absoluteString.contains(encoded))
        #expect(try items(url)["text"] == text)
        #expect(try items(url).count == 5)
    }
}

struct URLSessionHTTPClientTests {
    @Test func buildsGetRequestWithTimeout() throws {
        let url = try #require(URL(string: "https://example.com/lookup?text=run"))

        let request = URLSessionHTTPClient().request(for: url)

        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 5)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func usesCustomTimeout() throws {
        let url = try #require(URL(string: "https://example.com"))

        #expect(URLSessionHTTPClient(timeout: 2).request(for: url).timeoutInterval == 2)
    }
}
