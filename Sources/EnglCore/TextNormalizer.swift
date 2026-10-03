/// TextNormalizer prepares raw user input (clipboard or manual entry) for translation.
public enum TextNormalizer {
    public static let maxLength = 5000

    /// Trims the text, collapses whitespace and line breaks into single spaces and caps
    /// the length at `maxLength` characters. Returns `nil` when nothing is left.
    public static func normalize(_ text: String) -> String? {
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        var capped = String(collapsed.prefix(maxLength))
        // the cut may land right after a separator
        if capped.last == " " {
            capped.removeLast()
        }
        return capped.isEmpty ? nil : capped
    }
}
