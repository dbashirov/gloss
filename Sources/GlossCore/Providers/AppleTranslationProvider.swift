import os
import Translation

/// AppleTranslationProvider translates any query as plain text with Apple Translation;
/// for words it is a fallback when the dictionary is unavailable.
public struct AppleTranslationProvider: TranslationProvider {
    public static let providerID = "apple"
    public static let defaultPackRetryDelay = Duration.seconds(1)

    public let id = providerID

    private let translator: any TextTranslator
    private let packRetryDelay: Duration
    private let logger = Logger(subsystem: AppIdentity.bundleID, category: "translation")

    public init(
        translator: any TextTranslator = SystemTextTranslator(),
        packRetryDelay: Duration = defaultPackRetryDelay
    ) {
        self.translator = translator
        self.packRetryDelay = packRetryDelay
    }

    public func supports(_ query: Query) -> Bool {
        true
    }

    // after a wake from sleep the system may report an installed pack as missing
    // for a while, so a missing pack is checked once more before it is reported
    public func translate(_ query: Query) async throws -> TranslationResult {
        do {
            return try await translateOnce(query)
        } catch ProviderError.languagePackMissing {
            try await Task.sleep(for: packRetryDelay)
            let result = try await translateOnce(query)
            logger.notice("the pack is available on the second attempt")
            return result
        }
    }

    private func translateOnce(_ query: Query) async throws -> TranslationResult {
        let status = await translator.status(from: query.source, to: query.target)
        switch status {
        case .installed:
            break
        case .supported:
            let pair = "\(query.source.rawValue)→\(query.target.rawValue)"
            logger.notice("the pack \(pair, privacy: .public) is reported as not downloaded")
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
            logger.notice("translation failed: \(String(describing: error), privacy: .public)")
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
