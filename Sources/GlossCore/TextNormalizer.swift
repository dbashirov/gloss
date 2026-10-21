/// TextNormalizer prepares raw user input (clipboard or manual entry) for translation.
public enum TextNormalizer {
    public static let maxLength = 5000

    static let sentenceTerminators: Set<Character> = [".", "!", "?", "…"]
    static let closingWrappers: Set<Character> = ["\"", "'", "»", "”", "’", ")", "]"]

    // a colon usually opens a list
    private static let lineEnds = sentenceTerminators.union([":"])
    static let listMarkers: Set<Character> = ["-", "•", "*"]

    /// Trims the text, collapses whitespace into single spaces and caps the length at
    /// `maxLength` characters. Returns `nil` when nothing is left.
    /// Paragraphs stay apart: empty lines become one empty line, and a line break stays
    /// after a finished sentence or before a list item; any other break is a wrapped
    /// line and becomes a space, so a sentence is never cut in two.
    /// Stops reading at the cap, so a huge copied text costs no more than a short one.
    public static func normalize(_ text: String) -> String? {
        var result = ""
        var count = 0
        var hasPendingSpace = false
        var lineBreaks = 0
        for character in text {
            if character.isWhitespace {
                hasPendingSpace = count > 0
                if hasPendingSpace && character.isNewline {
                    lineBreaks += 1
                }
                continue
            }
            if hasPendingSpace {
                let separator = separator(after: result, before: character, lineBreaks: lineBreaks)
                // a separator at the cut point is dropped
                guard count + separator.count < maxLength else {
                    break
                }
                result += separator
                count += separator.count
                hasPendingSpace = false
                lineBreaks = 0
            }
            result.append(character)
            count += 1
            if count == maxLength {
                break
            }
        }
        return result.isEmpty ? nil : result
    }

    /// Reports whether the text ends with a sentence terminator, closing quotes aside.
    static func endsSentence(
        _ text: some StringProtocol,
        terminators: Set<Character> = sentenceTerminators
    ) -> Bool {
        let tail = text.reversed().first { !closingWrappers.contains($0) }
        return tail.map(terminators.contains) ?? false
    }

    private static func separator(
        after text: String,
        before next: Character,
        lineBreaks: Int
    ) -> String {
        switch lineBreaks {
        case 0:
            " "
        case 1:
            endsSentence(text, terminators: lineEnds) || listMarkers.contains(next) ? "\n" : " "
        default:
            "\n\n"
        }
    }
}
