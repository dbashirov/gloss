import Foundation
import Translation

/// TextTranslator hides the system translator so the provider can be tested with a fake.
public protocol TextTranslator: Sendable {
    func status(
        from source: Language,
        to target: Language
    ) async -> LanguageAvailability.Status

    /// Translates each text on its own and returns the translations in the same order.
    /// Throws `TranslationError` or `CancellationError`.
    func translate(
        _ texts: [String],
        from source: Language,
        to target: Language
    ) async throws -> [String]
}

/// SystemTextTranslator translates on device with Apple Translation; it works only
/// with installed language packs and never starts a download.
public struct SystemTextTranslator: TextTranslator {
    public init() {}

    // LanguageAvailability and TranslationSession are not Sendable, so they are
    // created per call instead of being stored
    public func status(
        from source: Language,
        to target: Language
    ) async -> LanguageAvailability.Status {
        await LanguageAvailability().status(from: source.locale, to: target.locale)
    }

    public func translate(
        _ texts: [String],
        from source: Language,
        to target: Language
    ) async throws -> [String] {
        let session = TranslationSession(installedSource: source.locale, target: target.locale)
        var translations: [String] = []
        for text in texts {
            translations.append(try await session.translate(text).targetText)
        }
        return translations
    }
}
