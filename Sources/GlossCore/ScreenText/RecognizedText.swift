/// RecognizedText joins the lines recognized on the screen into one query.
public enum RecognizedText {
    /// Joins lines with spaces and glues a word hyphenated across a line break back
    /// together; `nil` when no line has text.
    public static func join(_ lines: [String]) -> String? {
        var result = ""
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }
            if result.isEmpty {
                result = line
            } else if isHyphenated(result, before: line) {
                result.removeLast()
                result += line
            } else {
                result += " " + line
            }
        }
        return result.isEmpty ? nil : result
    }

    // "extraordi-" + "nary": a hyphen right after a letter and a lowercase continuation
    private static func isHyphenated(_ text: String, before line: String) -> Bool {
        guard text.last == "-" || text.last == "\u{00AD}",
              let letter = text.dropLast().last, letter.isLetter,
              let next = line.first, next.isLowercase
        else {
            return false
        }
        return true
    }
}
