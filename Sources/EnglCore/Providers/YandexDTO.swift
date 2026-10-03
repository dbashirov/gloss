import Foundation

/// YandexLookupResponse is the response of the Yandex Dictionary `lookup` method.
struct YandexLookupResponse: Decodable {
    let def: [YandexDefinition]

    func entry(fallbackWord: String) -> DictionaryEntry? {
        let groups = def.compactMap { $0.group() }
        guard !groups.isEmpty else {
            return nil
        }
        let word = def.lazy.compactMap { $0.text.nonEmpty }.first ?? fallbackWord
        let transcription = def.lazy.compactMap { $0.ts?.nonEmpty }.first
        return DictionaryEntry(word: word, transcription: transcription, groups: groups)
    }
}

struct YandexDefinition: Decodable {
    let text: String
    let pos: String?
    let ts: String?
    let tr: [YandexTranslation]?

    func group() -> PartOfSpeechGroup? {
        let senses = (tr ?? []).compactMap { $0.sense() }
        guard !senses.isEmpty else {
            return nil
        }
        return PartOfSpeechGroup(partOfSpeech: pos?.nonEmpty, translations: senses)
    }
}

struct YandexTranslation: Decodable {
    let text: String
    let syn: [YandexText]?
    let mean: [YandexText]?
    let ex: [YandexExample]?

    func sense() -> Sense? {
        guard let text = text.nonEmpty else {
            return nil
        }
        return Sense(
            text: text,
            synonyms: (syn ?? []).compactMap { $0.text.nonEmpty },
            meanings: (mean ?? []).compactMap { $0.text.nonEmpty },
            examples: (ex ?? []).compactMap { $0.example() }
        )
    }
}

struct YandexText: Decodable {
    let text: String
}

struct YandexExample: Decodable {
    let text: String
    let tr: [YandexText]?

    func example() -> Example? {
        guard let source = text.nonEmpty else {
            return nil
        }
        let translations = (tr ?? []).compactMap { $0.text.nonEmpty }
        let translation = translations.isEmpty ? nil : translations.joined(separator: ", ")
        return Example(source: source, translation: translation)
    }
}

/// YandexErrorResponse is an error body, e.g. `{"code": 401, "message": "API key is invalid"}`.
struct YandexErrorResponse: Decodable {
    let code: Int
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
