/// LanguagePackState tells whether Apple Translation can translate en↔ru offline.
public enum LanguagePackState: Sendable, Equatable {
    case installed
    case notInstalled
    case unsupported

    public var message: String {
        switch self {
        case .installed:
            "Языковой пакет английский ↔ русский установлен"
        case .notInstalled:
            "Языковой пакет английский ↔ русский не установлен"
        case .unsupported:
            "Перевод английский ↔ русский недоступен на этом Mac"
        }
    }

    /// Combines both directions: the pack is installed only when each one is.
    public static func check(with translator: any TextTranslator) async -> LanguagePackState {
        let forward = await translator.status(from: .en, to: .ru)
        let backward = await translator.status(from: .ru, to: .en)
        let statuses = [forward, backward]
        if statuses.allSatisfy({ $0 == .installed }) {
            return .installed
        }
        if statuses.contains(.unsupported) {
            return .unsupported
        }
        return .notInstalled
    }
}
