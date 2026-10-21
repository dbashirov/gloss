/// SettingsTab is a page of the settings window, picked in its toolbar.
enum SettingsTab: String, CaseIterable {
    case general
    case appearance
    case shortcuts
    case translation

    var title: String {
        switch self {
        case .general:
            "Основные"
        case .appearance:
            "Оформление"
        case .shortcuts:
            "Сочетания клавиш"
        case .translation:
            "Перевод"
        }
    }

    /// The SF Symbol of the toolbar item.
    var symbolName: String {
        switch self {
        case .general:
            "gearshape"
        case .appearance:
            "paintpalette"
        case .shortcuts:
            "keyboard"
        case .translation:
            "translate"
        }
    }
}
