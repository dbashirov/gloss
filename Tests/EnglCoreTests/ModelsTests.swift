import Foundation
import Testing
@testable import EnglCore

struct ModelsTests {
    @Test func senseDefaultsToEmptyCollections() {
        let sense = Sense(text: "бежать")
        #expect(sense.synonyms.isEmpty)
        #expect(sense.meanings.isEmpty)
        #expect(sense.examples.isEmpty)
    }

    @Test func translationResultsCompareByValue() {
        let entry = DictionaryEntry(
            word: "run",
            transcription: "rʌn",
            groups: [
                PartOfSpeechGroup(partOfSpeech: "verb", translations: [Sense(text: "бежать")]),
            ]
        )
        #expect(TranslationResult.dictionary(entry) == .dictionary(entry))
        let text = TextTranslation(source: "hi", translation: "привет")
        #expect(TranslationResult.text(text) != .dictionary(entry))
    }

    @Test func mapsLanguageToVoiceCode() {
        #expect(Language.en.voiceCode == "en-US")
        #expect(Language.ru.voiceCode == "ru-RU")
    }

    @Test func mapsLanguageToLocale() {
        #expect(Language.en.locale == Locale.Language(identifier: "en"))
        #expect(Language.ru.locale == Locale.Language(identifier: "ru"))
    }
}
