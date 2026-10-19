/// YandexKeyCheck verifies an API key with a real lookup through
/// `YandexDictionaryProvider`, without touching the stored key.
public struct YandexKeyCheck: Sendable {
    static let probe = Query(text: "hello", source: .en, target: .ru, kind: .dictionary)

    private let http: any HTTPClient

    public init(http: any HTTPClient) {
        self.http = http
    }

    /// Returns normally when the API accepts the key; throws `ProviderError`
    /// (`notConfigured` for an empty key) or `CancellationError`.
    public func check(_ key: String) async throws {
        let secrets = InMemorySecretStore()
        secrets.write(key, account: YandexDictionaryProvider.keyAccount)
        let provider = YandexDictionaryProvider(http: http, secrets: secrets)
        do {
            _ = try await provider.translate(Self.probe)
        } catch ProviderError.notFound {
            // the API answered, so it accepted the key
            return
        }
    }
}
