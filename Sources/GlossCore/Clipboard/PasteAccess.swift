/// PasteAccess is the user's choice in Privacy & Security → Paste from Other Apps,
/// which decides whether double Cmd+C can read the copied text.
public enum PasteAccess: Sendable, Equatable, CaseIterable {
    case allowed
    case denied
    case ask

    public var status: String {
        switch self {
        case .allowed:
            "Разрешён"
        case .denied:
            "Запрещён"
        case .ask:
            "Спрашивать"
        }
    }

    /// Returns what the user should do for double Cmd+C, `nil` when nothing.
    public var hint: String? {
        switch self {
        case .allowed:
            nil
        case .denied:
            "Двойной Cmd+C не сможет прочитать текст: разрешите Gloss в "
                + "«Конфиденциальность и безопасность → Вставка из других приложений»"
        case .ask:
            "При первом двойном Cmd+C система спросит разрешение — выберите "
                + "«Разрешать всегда»"
        }
    }
}
