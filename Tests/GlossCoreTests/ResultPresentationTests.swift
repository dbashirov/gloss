import Foundation
import Testing
@testable import GlossCore

struct ResultPresentationTests {
    @Test func namesYandexWithAttributionLink() {
        let info = ProviderInfo.info(for: YandexDictionaryProvider.providerID)
        #expect(info.name == "Реализовано с помощью сервиса «Яндекс.Словарь»")
        #expect(info.url == URL(string: "https://yandex.ru/dev/dictionary/"))
    }

    @Test func namesAppleTranslation() {
        let info = ProviderInfo.info(for: AppleTranslationProvider.providerID)
        #expect(info == ProviderInfo(name: "Apple Translation", url: nil))
    }

    @Test func showsUnknownProviderByID() {
        #expect(ProviderInfo.info(for: "claude") == ProviderInfo(name: "claude", url: nil))
    }

    @Test(arguments: [ProviderError.invalidKey, .rateLimited, .keyUnavailable])
    func showsFixableFallbackError(error: ProviderError) {
        let routed = RoutedResult(providerID: "apple", result: runText, fallbackError: error)
        #expect(routed.fallbackNotice == error)
    }

    @Test(arguments: [
        ProviderError?.none, .notConfigured, .notFound, .network, .invalidResponse,
        .languagePackMissing,
    ])
    func hidesOtherFallbackErrors(error: ProviderError?) {
        let routed = RoutedResult(providerID: "apple", result: runText, fallbackError: error)
        #expect(routed.fallbackNotice == nil)
    }

    @Test func copiesTextTranslation() {
        let result = TranslationResult.text(TextTranslation(source: "Hi", translation: "Привет"))
        #expect(result.copyText == "Привет")
    }

    @Test func copiesDistinctDictionaryTranslationsInOrder() {
        let entry = DictionaryEntry(word: "run", transcription: "rʌn", groups: [
            PartOfSpeechGroup(partOfSpeech: "verb", translations: [
                Sense(text: "бежать", synonyms: ["бегать"]),
                Sense(text: "управлять"),
            ]),
            PartOfSpeechGroup(partOfSpeech: "noun", translations: [
                Sense(text: "пробег"),
                Sense(text: "бежать"),
            ]),
        ])
        let result = TranslationResult.dictionary(entry)
        #expect(result.copyText == "бежать, управлять, пробег")
    }

    @Test func copiesEmptyDictionaryAsEmptyText() {
        let entry = DictionaryEntry(word: "run", transcription: nil, groups: [])
        #expect(TranslationResult.dictionary(entry).copyText.isEmpty)
    }

    @Test(arguments: [("run", Language.en), ("бежать", .ru), ("e-mail", .en), ("Ёж", .ru)])
    func tellsEntryLanguageByScript(word: String, language: Language) {
        let entry = DictionaryEntry(word: word, transcription: nil, groups: [])
        #expect(entry.language == language)
    }
}
