public enum ProviderError: Error, Equatable, Sendable, CaseIterable {
    case notConfigured, notFound, invalidKey, rateLimited, network
    case invalidResponse, languagePackMissing
}
