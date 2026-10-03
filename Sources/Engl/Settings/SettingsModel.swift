import EnglCore
import Foundation
import Observation
import ServiceManagement

/// SettingsModel holds the settings window state that does not live in `AppSettings`:
/// the Yandex key, the login item, paste access and the language pack.
@MainActor
@Observable
final class SettingsModel {
    private(set) var launchState = LaunchAtLoginState.unavailable
    private(set) var launchNote: SettingsNote?
    private(set) var pasteAccess = PasteAccess.ask
    private(set) var packState: LanguagePackState?
    private(set) var packNote: SettingsNote?
    private(set) var packDownload = LanguagePackDownload()

    /// Brings the settings window forward: the download dialog needs an active key window.
    @ObservationIgnored var activateWindow: () -> Void = {}
    @ObservationIgnored let key: YandexKeySettings
    @ObservationIgnored private let pasteboard: SystemPasteboard
    @ObservationIgnored private let textTranslator: any TextTranslator

    init(
        key: YandexKeySettings,
        pasteboard: SystemPasteboard,
        textTranslator: any TextTranslator
    ) {
        self.key = key
        self.pasteboard = pasteboard
        self.textTranslator = textTranslator
    }

    /// Reloads everything the window shows, including the stored key.
    func reload() {
        key.load()
        refreshStatuses()
    }

    /// Refreshes what the user may have changed in System Settings meanwhile.
    func refreshStatuses() {
        refreshLaunchState()
        pasteAccess = pasteboard.access
        Task {
            await refreshPackState()
        }
    }

    func setLaunchAtLogin(_ isOn: Bool) {
        // a login item registered from a build folder would break after the next rebuild
        guard launchState != .unavailable else {
            return
        }
        launchNote = nil
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchNote = .failure("Не удалось изменить автозапуск: \(error.localizedDescription)")
        }
        refreshLaunchState()
    }

    /// Triggers the view's `.translationTask`, which shows the system download dialog.
    func downloadPack() {
        activateWindow()
        packNote = nil
        packDownload.start()
    }

    func packDownloadFinished(requestID: Int, failure: String?) async {
        // the task also runs on every appearance while a download is active
        guard packDownload.finish(requestID: requestID) else {
            return
        }
        if let failure {
            packNote = .failure("Пакет не скачан: \(failure)")
        }
        await refreshPackState()
    }

    private func refreshLaunchState() {
        launchState = LaunchAtLoginState(
            status: SMAppService.mainApp.status,
            bundleURL: Bundle.main.bundleURL
        )
    }

    private func refreshPackState() async {
        packState = await LanguagePackState.check(with: textTranslator)
    }
}
