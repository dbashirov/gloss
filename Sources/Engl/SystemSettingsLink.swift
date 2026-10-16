import AppKit
import ServiceManagement

/// SystemSettingsLink opens a System Settings pane.
enum SystemSettingsLink {
    /// General → Language & Region, where Translation Languages are downloaded.
    case translationLanguages
    /// Privacy & Security → Paste from Other Apps.
    case pasteAccess
    /// Privacy & Security → Screen & System Audio Recording.
    case screenRecording
    /// General → Login Items & Extensions.
    case loginItems

    static let translationLanguagesURL = URL(
        string: "x-apple.systempreferences:com.apple.Localization-Settings.extension"
    )!
    static let pasteAccessURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard"
    )!
    static let screenRecordingURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
    )!

    @MainActor
    func open() {
        switch self {
        case .translationLanguages:
            NSWorkspace.shared.open(Self.translationLanguagesURL)
        case .pasteAccess:
            NSWorkspace.shared.open(Self.pasteAccessURL)
        case .screenRecording:
            NSWorkspace.shared.open(Self.screenRecordingURL)
        case .loginItems:
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
