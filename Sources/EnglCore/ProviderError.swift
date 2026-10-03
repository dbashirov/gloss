public enum ProviderError: Error, Equatable, Sendable, CaseIterable {
    case notConfigured, notFound, invalidKey, rateLimited, network
    case invalidResponse, languagePackMissing
    /// The key exists but Keychain refused to give it, e.g. the access prompt was denied.
    case keyUnavailable

    /// Keeps a `ProviderError` and turns any other error into `invalidResponse`,
    /// including a `CancellationError` of a request nobody cancelled.
    public init(mapping error: any Error) {
        self = error as? ProviderError ?? .invalidResponse
    }
}
