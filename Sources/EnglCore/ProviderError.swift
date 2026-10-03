public enum ProviderError: Error, Equatable, Sendable, CaseIterable {
    case notConfigured, notFound, invalidKey, rateLimited, network
    case invalidResponse, languagePackMissing
    /// The key exists but Keychain refused to give it, e.g. the access prompt was denied.
    case keyUnavailable
}
