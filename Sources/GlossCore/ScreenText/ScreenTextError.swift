/// ScreenTextError is why no text was taken from the selected screen area.
public enum ScreenTextError: Error, Sendable, Equatable, CaseIterable {
    case accessDenied
    case captureFailed
    case noText
    case recognitionFailed

    public var message: String {
        switch self {
        case .accessDenied:
            "Нет доступа к записи экрана: разрешите Gloss в «Конфиденциальность и безопасность → "
                + "Запись экрана и системного звука» и перезапустите Gloss"
        case .captureFailed:
            "Не удалось сделать снимок экрана"
        case .noText:
            "В выделенной области не найден текст"
        case .recognitionFailed:
            "Не удалось распознать текст"
        }
    }

    /// `nil` when the user can only select the area again.
    public var action: ErrorAction? {
        switch self {
        case .accessDenied:
            .allowScreenRecording
        case .captureFailed, .noText, .recognitionFailed:
            nil
        }
    }
}
