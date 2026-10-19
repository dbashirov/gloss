/// TranslationProvider is a single source of translations (dictionary API, system
/// translator, LLM). `Router` asks providers in order until one of them answers.
public protocol TranslationProvider: Sendable {
    var id: String { get }

    func supports(_ query: Query) -> Bool

    /// Throws `ProviderError` for failures that let `Router` try the next provider
    /// and `CancellationError` when the request was cancelled.
    func translate(_ query: Query) async throws -> TranslationResult
}
