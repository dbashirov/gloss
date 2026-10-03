import Testing
@testable import EnglCore

struct TextNormalizerTests {
    @Test(arguments: [
        ("hello", "hello"),
        ("  hello world  ", "hello world"),
        ("Привет, мир", "Привет, мир"),
        ("don't   give\tup", "don't give up"),
    ])
    func normalizesPlainText(input: String, expected: String) {
        #expect(TextNormalizer.normalize(input) == expected)
    }

    @Test func collapsesLineBreaks() {
        let input = "The quick brown fox\njumps over\r\n\n  the lazy dog.\n"
        let expected = "The quick brown fox jumps over the lazy dog."
        #expect(TextNormalizer.normalize(input) == expected)
    }

    @Test func collapsesMixedWhitespace() {
        let input = "\t one \u{00A0}\u{2003} two \t\t three \u{2028}four "
        #expect(TextNormalizer.normalize(input) == "one two three four")
    }

    @Test(arguments: ["", " ", "   \t  ", "\n\r\n", "\u{00A0}\u{2003}"])
    func returnsNilForBlankInput(input: String) {
        #expect(TextNormalizer.normalize(input) == nil)
    }

    @Test func keepsTextAtLimit() throws {
        let input = String(repeating: "a", count: TextNormalizer.maxLength)
        let result = try #require(TextNormalizer.normalize(input))
        #expect(result.count == TextNormalizer.maxLength)
    }

    @Test func truncatesLongText() throws {
        let input = String(repeating: "abcdef ", count: 1000)
        let result = try #require(TextNormalizer.normalize(input))
        #expect(result.count == TextNormalizer.maxLength)
        #expect(result.hasPrefix("abcdef abcdef"))
        #expect(result.hasSuffix("abcdef ab"))
    }

    @Test func dropsSeparatorLeftByTruncation() throws {
        // every fifth character is a space, so the 5000th one is cut right after it
        let input = String(repeating: "abcd ", count: 2000)
        let result = try #require(TextNormalizer.normalize(input))
        #expect(result.count == TextNormalizer.maxLength - 1)
        #expect(result.hasSuffix("abcd"))
    }

    @Test func countsCharactersNotBytes() throws {
        let input = String(repeating: "я", count: TextNormalizer.maxLength + 10)
        let result = try #require(TextNormalizer.normalize(input))
        #expect(result.count == TextNormalizer.maxLength)
    }

    @Test func capsHugeMultilineText() throws {
        let input = String(repeating: "lines of copied text\n\n", count: 500_000)
        let result = try #require(TextNormalizer.normalize(input))
        #expect(result.count == TextNormalizer.maxLength)
        #expect(!result.contains("\n"))
    }

    @Test func truncatesAfterCollapsing() throws {
        let padding = String(repeating: " ", count: 10_000)
        let result = try #require(TextNormalizer.normalize(padding + "word" + padding))
        #expect(result == "word")
    }
}

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
}
