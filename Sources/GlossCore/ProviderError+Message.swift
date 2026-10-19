/// ErrorAction is what the user can do to fix a failed translation.
public enum ErrorAction: Sendable, Equatable, CaseIterable {
    case openSettings
    case downloadLanguagePack
    case allowPasteboardAccess
    case allowScreenRecording

    public var title: String {
        switch self {
        case .openSettings:
            "Открыть настройки"
        case .downloadLanguagePack:
            "Скачать языковой пакет"
        case .allowPasteboardAccess:
            "Разрешить доступ к буферу"
        case .allowScreenRecording:
            "Разрешить запись экрана"
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
        case .keyUnavailable:
            "Нет доступа к ключу Яндекс.Словаря в Связке ключей"
        }
    }

    /// `nil` when the user can only retry later or change the query.
    public var action: ErrorAction? {
        switch self {
        case .notConfigured, .invalidKey, .keyUnavailable:
            .openSettings
        case .languagePackMissing:
            .downloadLanguagePack
        case .notFound, .rateLimited, .network, .invalidResponse:
            nil
        }
    }
}
