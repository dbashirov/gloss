public enum ProviderError: Error, Equatable, Sendable {
    case notConfigured, notFound, invalidKey, rateLimited, network
    case invalidResponse, languagePackMissing
}
