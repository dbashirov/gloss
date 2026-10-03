import Foundation
import Testing
@testable import EnglCore

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func queryValue(_ name: String, in url: URL) -> String? {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return components?.queryItems?.first { $0.name == name }?.value
}

struct YandexKeyCheckTests {
    @Test func acceptsValidKey() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))

        try await YandexKeyCheck(http: http).check("valid-key")

        let url = try #require(http.urls.first)
        #expect(http.urls.count == 1)
        #expect(queryValue("key", in: url) == "valid-key")
        #expect(queryValue("text", in: url) == "hello")
        #expect(queryValue("lang", in: url) == "en-ru")
    }

    @Test func trimsKey() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_run"))

        try await YandexKeyCheck(http: http).check("  valid-key\n")

        let url = try #require(http.urls.first)
        #expect(queryValue("key", in: url) == "valid-key")
    }

    @Test func acceptsKeyWhenWordIsNotFound() async throws {
        let http = FakeHTTPClient(status: 200, body: try fixture("yandex_empty"))

        try await YandexKeyCheck(http: http).check("valid-key")
    }

    @Test func rejectsInvalidKey() async throws {
        let http = FakeHTTPClient(status: 401, body: try fixture("yandex_error_401"))

        await #expect(throws: ProviderError.invalidKey) {
            try await YandexKeyCheck(http: http).check("bad-key")
        }
    }

    @Test func reportsRateLimit() async throws {
        let http = FakeHTTPClient(status: 403, body: try fixture("yandex_error_401"))

        await #expect(throws: ProviderError.rateLimited) {
            try await YandexKeyCheck(http: http).check("valid-key")
        }
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .timedOut])
    func reportsNetworkFailure(code: URLError.Code) async {
        let http = FakeHTTPClient(error: URLError(code))

        await #expect(throws: ProviderError.network) {
            try await YandexKeyCheck(http: http).check("valid-key")
        }
    }

    @Test(arguments: ["", "   \n"])
    func rejectsEmptyKeyWithoutRequest(key: String) async {
        let http = FakeHTTPClient(json: "{}")

        await #expect(throws: ProviderError.notConfigured) {
            try await YandexKeyCheck(http: http).check(key)
        }
        #expect(http.urls.isEmpty)
    }

    @Test func passesCancellationThrough() async {
        let http = FakeHTTPClient(error: URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            try await YandexKeyCheck(http: http).check("valid-key")
        }
    }
}
