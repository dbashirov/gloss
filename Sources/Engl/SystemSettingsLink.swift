import AppKit
import ServiceManagement

/// SystemSettingsLink opens a System Settings pane.
enum SystemSettingsLink {
    /// General → Language & Region, where Translation Languages are downloaded.
    case translationLanguages
    /// Privacy & Security → Paste from Other Apps.
    case pasteAccess
    /// General → Login Items & Extensions.
    case loginItems

    static let translationLanguagesURL = URL(
        string: "x-apple.systempreferences:com.apple.Localization-Settings.extension"
    )!
    static let pasteAccessURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard"
    )!

    @MainActor
    func open() {
        switch self {
        case .translationLanguages:
            NSWorkspace.shared.open(Self.translationLanguagesURL)
        case .pasteAccess:
            NSWorkspace.shared.open(Self.pasteAccessURL)
        case .loginItems:
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
