import Translation

/// AppleTranslationProvider translates any query as plain text with Apple Translation;
/// for words it is a fallback when the dictionary is unavailable.
public struct AppleTranslationProvider: TranslationProvider {
    public static let providerID = "apple"

    public let id = providerID

    private let translator: any TextTranslator

    public init(translator: any TextTranslator = SystemTextTranslator()) {
        self.translator = translator
    }

    public func supports(_ query: Query) -> Bool {
        true
    }

    public func translate(_ query: Query) async throws -> TranslationResult {
        switch await translator.status(from: query.source, to: query.target) {
        case .installed:
            break
        case .supported:
            throw ProviderError.languagePackMissing
        case .unsupported:
            throw ProviderError.notFound
        @unknown default:
            throw ProviderError.notFound
        }
        try Task.checkCancellation()
        let translation: String
        do {
            translation = try await translator.translate(
                query.text,
                from: query.source,
                to: query.target
            )
        } catch {
            try Task.checkCancellation()
            throw Self.mapError(error)
        }
        return .text(TextTranslation(source: query.text, translation: translation))
    }

    static func mapError(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError, TranslationError.alreadyCancelled:
            CancellationError()
        case TranslationError.notInstalled:
            ProviderError.languagePackMissing
        case TranslationError.unsupportedSourceLanguage,
             TranslationError.unsupportedTargetLanguage,
             TranslationError.unsupportedLanguagePairing,
             TranslationError.nothingToTranslate:
            ProviderError.notFound
        default:
            ProviderError.invalidResponse
        }
    }
}
