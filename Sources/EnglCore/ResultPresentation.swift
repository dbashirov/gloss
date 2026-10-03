import Foundation

/// ProviderInfo describes a translation source for the panel footer.
public struct ProviderInfo: Sendable, Equatable {
    static let yandexDictionaryURL = URL(string: "https://yandex.ru/dev/dictionary/")!

    public let name: String
    public let url: URL?

    /// Returns the footer info; unknown providers are shown by their identifier.
    public static func info(for providerID: String) -> ProviderInfo {
        switch providerID {
        case YandexDictionaryProvider.providerID:
            // the Yandex Dictionary terms require this attribution with a link
            ProviderInfo(
                name: "Реализовано с помощью сервиса «Яндекс.Словарь»",
                url: yandexDictionaryURL
            )
        case AppleTranslationProvider.providerID:
            ProviderInfo(name: "Apple Translation", url: nil)
        default:
            ProviderInfo(name: providerID, url: nil)
        }
    }
}

extension RoutedResult {
    /// The failure of the preferred provider the user should fix, shown next to
    /// the fallback answer; a missing key or an unknown word is not worth it.
    public var fallbackNotice: ProviderError? {
        switch fallbackError {
        case .invalidKey, .rateLimited, .keyUnavailable:
            fallbackError
        default:
            nil
        }
    }
}

extension DictionaryEntry {
    /// The language the word is pronounced in, told by its script.
    public var language: Language {
        QueryClassifier.scriptLanguage(word)
    }
}

extension TranslationResult {
    /// The text the copy button puts on the pasteboard: all distinct dictionary
    /// translations or the translated text.
    public var copyText: String {
        switch self {
        case .dictionary(let entry):
            var seen = Set<String>()
            let senses = entry.groups
                .flatMap(\.translations)
                .map(\.text)
                .filter { seen.insert($0).inserted }
            return senses.joined(separator: ", ")
        case .text(let translation):
            return translation.translation
        }
    }
}
