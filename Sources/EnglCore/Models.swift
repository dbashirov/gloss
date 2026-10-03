public enum Language: String, Sendable {
    case en, ru
}

public enum QueryKind: Sendable {
    case dictionary, sentence
}

public struct Query: Sendable, Hashable {
    public let text: String
    public let source: Language
    public let target: Language
    public let kind: QueryKind

    public init(text: String, source: Language, target: Language, kind: QueryKind) {
        self.text = text
        self.source = source
        self.target = target
        self.kind = kind
    }
}

public struct DictionaryEntry: Sendable, Equatable {
    public let word: String
    public let transcription: String?
    public let groups: [PartOfSpeechGroup]

    public init(word: String, transcription: String?, groups: [PartOfSpeechGroup]) {
        self.word = word
        self.transcription = transcription
        self.groups = groups
    }
}

public struct PartOfSpeechGroup: Sendable, Equatable {
    public let partOfSpeech: String?
    public let translations: [Sense]

    public init(partOfSpeech: String?, translations: [Sense]) {
        self.partOfSpeech = partOfSpeech
        self.translations = translations
    }
}

public struct Sense: Sendable, Equatable {
    public let text: String
    public let synonyms: [String]
    public let meanings: [String]
    public let examples: [Example]

    public init(
        text: String,
        synonyms: [String] = [],
        meanings: [String] = [],
        examples: [Example] = []
    ) {
        self.text = text
        self.synonyms = synonyms
        self.meanings = meanings
        self.examples = examples
    }
}

public struct Example: Sendable, Equatable {
    public let source: String
    public let translation: String?

    public init(source: String, translation: String?) {
        self.source = source
        self.translation = translation
    }
}

public struct TextTranslation: Sendable, Equatable {
    public let source: String
    public let translation: String

    public init(source: String, translation: String) {
        self.source = source
        self.translation = translation
    }
}

public enum TranslationResult: Sendable, Equatable {
    case dictionary(DictionaryEntry)
    case text(TextTranslation)
}

public struct RoutedResult: Sendable, Equatable {
    public let providerID: String
    public let result: TranslationResult

    public init(providerID: String, result: TranslationResult) {
        self.providerID = providerID
        self.result = result
    }
}
