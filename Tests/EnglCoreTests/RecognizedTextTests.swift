import Testing
@testable import EnglCore

struct RecognizedTextTests {
    @Test(arguments: [
        (["serendipity"], "serendipity"),
        (["The quick brown fox", "jumps over the lazy dog."], "The quick brown fox jumps over the lazy dog."),
        (["  Съешь же ещё ", "", "этих булок  "], "Съешь же ещё этих булок"),
        (["It was an extraordi-", "nary day"], "It was an extraordinary day"),
        (["мягких фран-", "цузских булок"], "мягких французских булок"),
        (["soft hy\u{00AD}", "phen"], "soft hyphen"),
    ])
    func joinsLines(lines: [String], expected: String) {
        #expect(RecognizedText.join(lines) == expected)
    }

    @Test(arguments: [
        // a capital letter starts a new item, not the rest of a word
        (["Settings -", "Privacy"], "Settings - Privacy"),
        (["well-", "Known"], "well- Known"),
        (["1990-", "2000"], "1990- 2000"),
        (["-", "next"], "- next"),
    ])
    func keepsHyphenThatDoesNotSplitWord(lines: [String], expected: String) {
        #expect(RecognizedText.join(lines) == expected)
    }

    @Test(arguments: [[String](), [""], ["   ", "\n"]])
    func returnsNilWithoutText(lines: [String]) {
        #expect(RecognizedText.join(lines) == nil)
    }
}
