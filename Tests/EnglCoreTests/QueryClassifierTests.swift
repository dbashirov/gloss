import Testing
@testable import EnglCore

struct QueryClassifierTests {
    @Test func classifiesEnglishWord() {
        let query = QueryClassifier.classify("run")
        #expect(query == Query(text: "run", source: .en, target: .ru, kind: .dictionary))
    }

    @Test func classifiesRussianWord() {
        let query = QueryClassifier.classify("бежать")
        #expect(query == Query(text: "бежать", source: .ru, target: .en, kind: .dictionary))
    }

    @Test(arguments: [
        ("give up on", Language.en),
        ("in the end", .en),
        ("кот и пёс", .ru),
        ("в конце концов", .ru),
    ])
    func classifiesThreeWordPhraseAsDictionary(text: String, language: Language) {
        let query = QueryClassifier.classify(text)
        #expect(query.kind == .dictionary)
        #expect(query.source == language)
        #expect(query.text == text)
    }

    @Test func classifiesEnglishSentence() {
        let text = "The weather is lovely today and we are going to the park"
        let query = QueryClassifier.classify(text)
        #expect(query == Query(text: text, source: .en, target: .ru, kind: .sentence))
    }

    @Test func classifiesRussianSentence() {
        let text = "Сегодня отличная погода, и мы идём гулять в парк"
        let query = QueryClassifier.classify(text)
        #expect(query == Query(text: text, source: .ru, target: .en, kind: .sentence))
    }

    @Test(arguments: ["don't", "well-known", "o'clock", "mother-in-law"])
    func keepsApostrophesAndHyphensInWords(text: String) {
        let query = QueryClassifier.classify(text)
        #expect(query == Query(text: text, source: .en, target: .ru, kind: .dictionary))
    }

    @Test func classifiesRussianHyphenatedWord() {
        let query = QueryClassifier.classify("из-за")
        #expect(query == Query(text: "из-за", source: .ru, target: .en, kind: .dictionary))
    }

    @Test(arguments: ["Hello.", "Stop!", "Really?", "Wait…", "Go home.", "\"Hello.\""])
    func treatsTerminalPunctuationAsSentence(text: String) {
        let query = QueryClassifier.classify(text)
        #expect(query.kind == .sentence)
        #expect(query.text == text)
        #expect(query.source == .en)
    }

    @Test(arguments: [
        ("\"run\"", "run"),
        ("«бег»", "бег"),
        ("run,", "run"),
        ("(well-known)", "well-known"),
    ])
    func stripsWrappingPunctuationForLookup(text: String, expected: String) {
        let query = QueryClassifier.classify(text)
        #expect(query.kind == .dictionary)
        #expect(query.text == expected)
    }

    @Test func keepsPunctuationOnlyText() {
        let query = QueryClassifier.classify(",")
        #expect(query.text == ",")
        #expect(query.kind == .dictionary)
    }

    @Test(arguments: [
        ("hello мир", Language.ru),
        ("кот cat", .ru),
        ("iPhone", .en),
    ])
    func shortMixedTextPrefersCyrillic(text: String, language: Language) {
        #expect(QueryClassifier.classify(text).source == language)
    }

    @Test func longMixedTextUsesDominantLanguage() {
        let english = "I really like to eat borscht with my family on Sundays, борщ is great"
        #expect(QueryClassifier.classify(english).source == .en)

        let russian = "Я очень люблю смотреть сериалы вечером, особенно Breaking Bad"
        #expect(QueryClassifier.classify(russian).source == .ru)
    }

    @Test(arguments: ["42", "2024", "3.14", "100500 1 2"])
    func digitsFallBackToEnglish(text: String) {
        #expect(QueryClassifier.classify(text).source == .en)
    }

    @Test func wordWithDigitsIsDictionary() {
        let query = QueryClassifier.classify("covid-19")
        #expect(query == Query(text: "covid-19", source: .en, target: .ru, kind: .dictionary))
    }

    @Test func russianDigitsPhraseUsesCyrillic() {
        #expect(QueryClassifier.classify("2 кота").source == .ru)
    }

    @Test func fourWordsWithoutPunctuationIsSentence() {
        let query = QueryClassifier.classify("look up the word")
        #expect(query.kind == .sentence)
        #expect(query.source == .en)
    }
}
