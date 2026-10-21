import CoreGraphics
import Testing
@testable import GlossCore

struct RecognizedTextTests {
    @Test(arguments: [
        (["serendipity"], "serendipity"),
        (["The quick brown fox", "jumps over the lazy dog."], "The quick brown fox jumps over the lazy dog."),
        (["  Съешь же ещё ", "этих булок  "], "Съешь же ещё этих булок"),
        (["It was an extraordi-", "nary day"], "It was an extraordinary day"),
        (["мягких фран-", "цузских булок"], "мягких французских булок"),
        (["soft hy\u{00AD}", "phen"], "soft hyphen"),
    ])
    func joinsLines(lines: [String], expected: String) {
        #expect(RecognizedText.join(layOut([lines])) == expected)
    }

    @Test(arguments: [
        // a capital letter starts a new item, not the rest of a word
        (["Settings -", "Privacy"], "Settings - Privacy"),
        (["well-", "Known"], "well- Known"),
        (["1990-", "2000"], "1990- 2000"),
        (["-", "next"], "- next"),
    ])
    func keepsHyphenThatDoesNotSplitWord(lines: [String], expected: String) {
        #expect(RecognizedText.join(layOut([lines])) == expected)
    }

    @Test(arguments: [[String](), [""], ["   ", "\n"]])
    func returnsNilWithoutText(lines: [String]) {
        #expect(RecognizedText.join(layOut([lines])) == nil)
    }

    @Test func keepsParagraphsApart() {
        let lines = layOut([
            ["Introduction"],
            ["The first paragraph ends", "on its second line."],
            ["The next one"],
        ])

        let expected = "Introduction\n\nThe first paragraph ends on its second line."
            + "\n\nThe next one"
        #expect(RecognizedText.join(lines) == expected)
    }

    @Test func doesNotGlueHyphenAcrossParagraphs() {
        let lines = layOut([["A long-"], ["term plan"]])

        #expect(RecognizedText.join(lines) == "A long-\n\nterm plan")
    }

    @Test func startsParagraphAtTopOfNextColumn() {
        let left = layOut([["Left column", "ends here"]])
        let right = layOut([["right column"]]).map { line in
            RecognizedLine(text: line.text, bounds: line.bounds.offsetBy(dx: 0.5, dy: 0))
        }

        #expect(RecognizedText.join(left + right) == "Left column ends here\n\nright column")
    }

    @Test func joinsLinesOfOneRow() {
        let row = CGRect(x: 0.1, y: 0.5, width: 0.3, height: 0.05)
        let lines = [
            RecognizedLine(text: "Name", bounds: row),
            RecognizedLine(text: "Gloss", bounds: row.offsetBy(dx: 0.5, dy: 0.005)),
        ]

        #expect(RecognizedText.join(lines) == "Name Gloss")
    }

    @Test func startsListItemOnItsOwnLine() {
        let lines = layOut([["Buy:", "- milk", "• bread", "and tea"]])

        #expect(RecognizedText.join(lines) == "Buy:\n- milk\n• bread and tea")
    }
}
