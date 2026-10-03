/// TextNormalizer prepares raw user input (clipboard or manual entry) for translation.
public enum TextNormalizer {
    public static let maxLength = 5000

    /// Trims the text, collapses whitespace and line breaks into single spaces and caps
    /// the length at `maxLength` characters. Returns `nil` when nothing is left.
    /// Stops reading at the cap, so a huge copied text costs no more than a short one.
    public static func normalize(_ text: String) -> String? {
        var result = ""
        var count = 0
        var hasPendingSpace = false
        for character in text {
            if character.isWhitespace {
                hasPendingSpace = count > 0
                continue
            }
            if hasPendingSpace {
                // a separator at the cut point is dropped
                guard count + 1 < maxLength else {
                    break
                }
                result.append(" ")
                count += 1
                hasPendingSpace = false
            }
            result.append(character)
            count += 1
            if count == maxLength {
                break
            }
        }
        return result.isEmpty ? nil : result
    }
}
