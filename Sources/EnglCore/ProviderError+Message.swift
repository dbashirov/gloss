/// ErrorAction is what the user can do to fix a failed translation.
public enum ErrorAction: Sendable, Equatable, CaseIterable {
    case openSettings
    case downloadLanguagePack
    case allowPasteboardAccess

    public var title: String {
        switch self {
        case .openSettings:
            "Открыть настройки"
        case .downloadLanguagePack:
            "Скачать языковой пакет"
        case .allowPasteboardAccess:
            "Разрешить доступ к буферу"
        }
    }
}

extension ProviderError {
    public var message: String {
        switch self {
        case .notConfigured:
            "Не задан ключ Яндекс.Словаря"
        case .notFound:
            "Перевод не найден"
        case .invalidKey:
            "Ключ Яндекс.Словаря недействителен"
        case .rateLimited:
            "Исчерпан дневной лимит запросов к Яндекс.Словарю, попробуйте завтра"
        case .network:
            "Нет соединения с сервером, проверьте подключение к интернету"
        case .invalidResponse:
            "Сервис перевода вернул некорректный ответ, попробуйте позже"
        case .languagePackMissing:
            "Не установлен языковой пакет английский ↔ русский"
        }
    }

    /// `nil` when the user can only retry later or change the query.
    public var action: ErrorAction? {
        switch self {
        case .notConfigured, .invalidKey:
            .openSettings
        case .languagePackMissing:
            .downloadLanguagePack
        case .notFound, .rateLimited, .network, .invalidResponse:
            nil
        }
    }
}

/// PasteboardAccessHint is shown while paste access is denied in Privacy & Security:
/// double Cmd+C cannot read the copied text then.
public enum PasteboardAccessHint {
    public static let message = "Доступ к буферу обмена запрещён — двойной Cmd+C не работает"
    public static let action = ErrorAction.allowPasteboardAccess
}
