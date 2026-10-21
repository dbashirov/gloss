import CoreGraphics

/// RecognizedLine is a line of text found on the screen and its place in the image,
/// normalized to 0...1 with the origin at the bottom left, as Vision gives it.
public struct RecognizedLine: Sendable, Equatable {
    public let text: String
    public let bounds: CGRect

    public init(text: String, bounds: CGRect) {
        self.text = text
        self.bounds = bounds
    }
}

/// RecognizedText joins the lines recognized on the screen into one query.
public enum RecognizedText {
    /// A gap between lines taller than this share of a line height starts a paragraph.
    static let paragraphGap: CGFloat = 0.7

    /// Joins the lines of a paragraph with spaces and glues a word hyphenated across a
    /// line break back together. Paragraphs, told by a wider gap, are kept apart by an
    /// empty line and a list item starts its own line, as `TextNormalizer` keeps them.
    /// Returns `nil` when no line has text.
    public static func join(_ lines: [RecognizedLine]) -> String? {
        var result = ""
        var previous: CGRect?
        for rawLine in lines {
            let line = rawLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }
            if result.isEmpty {
                result = line
            } else if let previous, startsParagraph(rawLine.bounds, after: previous) {
                result += "\n\n" + line
            } else if let marker = line.first, TextNormalizer.listMarkers.contains(marker) {
                result += "\n" + line
            } else if isHyphenated(result, before: line) {
                result.removeLast()
                result += line
            } else {
                result += " " + line
            }
            previous = rawLine.bounds
        }
        return result.isEmpty ? nil : result
    }

    // a line well below the previous one, or above it as at the top of the next column
    private static func startsParagraph(_ bounds: CGRect, after previous: CGRect) -> Bool {
        let lineHeight = (previous.height + bounds.height) / 2
        let gap = previous.minY - bounds.maxY
        return gap > lineHeight * paragraphGap || bounds.minY > previous.maxY
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
