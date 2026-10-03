import Foundation
import Testing
@testable import EnglCore

private let text = TranslationResult.text(TextTranslation(source: "run", translation: "бежать"))

private func isRussian(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
}

struct ProviderErrorMessageTests {
    @Test(arguments: ProviderError.allCases)
    func everyErrorHasRussianMessage(error: ProviderError) {
        #expect(isRussian(error.message))
    }

    @Test func messagesAreDistinct() {
        let messages = Set(ProviderError.allCases.map(\.message))
        #expect(messages.count == ProviderError.allCases.count)
    }

    @Test(arguments: [
        (ProviderError.notConfigured, ErrorAction?.some(.openSettings)),
        (.invalidKey, .openSettings),
        (.languagePackMissing, .downloadLanguagePack),
        (.notFound, nil),
        (.rateLimited, nil),
        (.network, nil),
        (.invalidResponse, nil),
        (.keyUnavailable, .openSettings),
    ])
    func mapsErrorToAction(error: ProviderError, action: ErrorAction?) {
        #expect(error.action == action)
    }

    @Test(arguments: ErrorAction.allCases)
    func everyActionHasRussianTitle(action: ErrorAction) {
        #expect(isRussian(action.title))
    }

    @Test func actionTitlesAreDistinct() {
        let titles = Set(ErrorAction.allCases.map(\.title))
        #expect(titles.count == ErrorAction.allCases.count)
    }
}

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
        let routed = RoutedResult(providerID: "apple", result: text, fallbackError: error)
        #expect(routed.fallbackNotice == error)
    }

    @Test(arguments: [
        ProviderError?.none, .notConfigured, .notFound, .network, .invalidResponse,
        .languagePackMissing,
    ])
    func hidesOtherFallbackErrors(error: ProviderError?) {
        let routed = RoutedResult(providerID: "apple", result: text, fallbackError: error)
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

    @Test func mapsLanguageToVoiceCode() {
        #expect(Language.en.voiceCode == "en-US")
        #expect(Language.ru.voiceCode == "ru-RU")
    }
}
