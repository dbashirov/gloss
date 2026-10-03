import Foundation

/// YandexDictionaryProvider builds dictionary cards from the Yandex Dictionary API.
public struct YandexDictionaryProvider: TranslationProvider {
    public static let providerID = "yandex"
    public static let keyAccount = "yandex-dictionary"
    static let lookupEndpoint = URL(
        string: "https://dictionary.yandex.net/api/v1/dicservice.json/lookup"
    )!
    // MORPHO: look up by word form ("running" → "run")
    static let morphoFlag = "4"

    public let id = providerID

    private let http: any HTTPClient
    private let secrets: any SecretStore

    public init(http: any HTTPClient, secrets: any SecretStore) {
        self.http = http
        self.secrets = secrets
    }

    public func supports(_ query: Query) -> Bool {
        query.kind == .dictionary
    }

    public func translate(_ query: Query) async throws -> TranslationResult {
        let key = try apiKey()
        let response: HTTPResponse
        do {
            response = try await http.get(Self.lookupURL(for: query, key: key))
        } catch {
            try Task.checkCancellation()
            throw Self.mapTransportError(error)
        }
        let entry = try Self.parse(response, fallbackWord: query.text)
        return .dictionary(entry)
    }

    static func lookupURL(for query: Query, key: String) -> URL {
        var components = URLComponents(url: lookupEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "lang", value: "\(query.source.rawValue)-\(query.target.rawValue)"),
            URLQueryItem(name: "text", value: query.text),
            URLQueryItem(name: "ui", value: "ru"),
            URLQueryItem(name: "flags", value: morphoFlag),
        ]
        // URLComponents keeps "+" as is, but servers decode it as a space
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    static func parse(_ response: HTTPResponse, fallbackWord: String) throws -> DictionaryEntry {
        guard response.statusCode == 200 else {
            throw error(forStatus: response.statusCode)
        }
        let decoder = JSONDecoder()
        guard let lookup = try? decoder.decode(YandexLookupResponse.self, from: response.body) else {
            // the API may report an error in the body of a 200 response
            if let failure = try? decoder.decode(YandexErrorResponse.self, from: response.body),
               failure.code != 200 {
                throw error(forStatus: failure.code)
            }
            throw ProviderError.invalidResponse
        }
        guard let entry = lookup.entry(fallbackWord: fallbackWord) else {
            throw ProviderError.notFound
        }
        return entry
    }

    static func error(forStatus code: Int) -> ProviderError {
        switch code {
        case 401, 402:
            .invalidKey
        case 403:
            .rateLimited
        case 413, 501:
            .notFound
        default:
            .invalidResponse
        }
    }

    static func mapTransportError(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            error
        case let urlError as URLError where urlError.code == .cancelled:
            CancellationError()
        default:
            ProviderError.network
        }
    }

    private func apiKey() throws -> String {
        // an unreadable keychain item is treated the same as a missing key
        let stored = try? secrets.read(Self.keyAccount)
        let key = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            throw ProviderError.notConfigured
        }
        return key
    }
}
