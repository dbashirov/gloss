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
        // each paragraph is translated on its own, so the translation keeps the line breaks
        let lines = query.text.split(separator: "\n", omittingEmptySubsequences: false)
        let paragraphs = lines.filter { !$0.isEmpty }.map(String.init)
        let translations: [String]
        do {
            translations = try await translator.translate(
                paragraphs,
                from: query.source,
                to: query.target
            )
        } catch {
            try Task.checkCancellation()
            throw Self.mapError(error)
        }
        var remaining = translations.makeIterator()
        let translation = lines
            .map { $0.isEmpty ? "" : remaining.next() ?? "" }
            .joined(separator: "\n")
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
