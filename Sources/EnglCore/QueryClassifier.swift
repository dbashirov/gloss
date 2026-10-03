import Foundation
import NaturalLanguage

/// QueryClassifier detects the language and the kind of a normalized query.
public enum QueryClassifier {
    public static let maxDictionaryWords = 3
    static let shortTextWords = 2

    private static let sentenceTerminators: Set<Character> = [".", "!", "?", "…"]
    private static let closingWrappers: Set<Character> = ["\"", "'", "»", "”", "’", ")", "]"]

    /// Classifies text that has already passed `TextNormalizer`.
    public static func classify(_ text: String) -> Query {
        let words = words(in: text)
        let source = detectLanguage(text, wordCount: words.count)
        let kind = detectKind(text, wordCount: words.count)
        return Query(
            text: kind == .dictionary ? lookupText(text) : text,
            source: source,
            target: source == .en ? .ru : .en,
            kind: kind
        )
    }

    static func detectLanguage(_ text: String, wordCount: Int) -> Language {
        if wordCount <= shortTextWords || !text.contains(where: \.isLetter) {
            return scriptLanguage(text)
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.english, .russian]
        recognizer.processString(text)
        switch recognizer.dominantLanguage {
        case .english:
            return .en
        case .russian:
            return .ru
        default:
            return scriptLanguage(text)
        }
    }

    static func detectKind(_ text: String, wordCount: Int) -> QueryKind {
        guard wordCount <= maxDictionaryWords else {
            return .sentence
        }
        // the dictionary is a network service: keep likely secrets on device
        if !text.contains(where: \.isLetter) || words(in: text).contains(where: looksLikeSecret) {
            return .sentence
        }
        let tail = text.reversed().first { !closingWrappers.contains($0) }
        if let tail, sentenceTerminators.contains(tail) {
            return .sentence
        }
        return .dictionary
    }

    static func scriptLanguage(_ text: String) -> Language {
        text.unicodeScalars.contains(where: isCyrillic) ? .ru : .en
    }

    private static func isCyrillic(_ scalar: Unicode.Scalar) -> Bool {
        (0x0400...0x052F).contains(scalar.value)
    }

    /// looksLikeSecret flags tokens such as passwords, API keys and hashes: no dictionary
    /// word mixes letters with digits at this length or switches case inside a long token.
    static func looksLikeSecret(_ word: Substring) -> Bool {
        let hasDigit = word.contains(where: \.isNumber)
        let hasLower = word.contains(where: \.isLowercase)
        let hasUpper = word.contains(where: \.isUppercase)
        if hasDigit && (word.count >= 12 || word.count >= 8 && hasLower && hasUpper) {
            return true
        }
        let hasUpperInside = word.dropFirst().contains(where: \.isUppercase)
        return word.count >= 16 && hasLower && hasUpperInside
    }

    private static func words(in text: String) -> [Substring] {
        text.split(whereSeparator: { $0.isWhitespace })
    }

    /// lookupText strips quotes and commas around a copied word: they break lookups.
    private static func lookupText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .punctuationCharacters)
        return trimmed.isEmpty ? text : trimmed
    }
}
