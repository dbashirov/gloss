import AppKit

/// SystemSettingsLink opens a System Settings pane.
enum SystemSettingsLink: String {
    /// General → Language & Region, where Translation Languages are downloaded.
    case translationLanguages = "x-apple.systempreferences:com.apple.Localization-Settings.extension"
    /// Privacy & Security → Paste from Other Apps.
    case pasteAccess =
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard"

    @MainActor
    func open() {
        guard let url = URL(string: rawValue) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
