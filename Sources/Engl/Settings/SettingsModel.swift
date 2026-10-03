import AppKit
import EnglCore
import Observation
import ServiceManagement
import Translation

/// SettingsNote is a one-line outcome shown under a settings control.
struct SettingsNote: Equatable {
    let text: String
    let isError: Bool

    static func success(_ text: String) -> SettingsNote {
        SettingsNote(text: text, isError: false)
    }

    static func failure(_ text: String) -> SettingsNote {
        SettingsNote(text: text, isError: true)
    }
}

/// SettingsModel holds the settings window state that does not live in `AppSettings`:
/// the Yandex key draft, the login item, paste access and the language pack.
@MainActor
@Observable
final class SettingsModel {
    static let keyURL = URL(string: "https://yandex.ru/dev/dictionary/keys/get/?service=dict")!

    var keyDraft = ""
    private(set) var keyNote: SettingsNote?
    private(set) var isCheckingKey = false
    private(set) var launchState = LaunchAtLoginState.unavailable
    private(set) var launchNote: SettingsNote?
    private(set) var pasteAccess = NSPasteboard.AccessBehavior.default
    private(set) var packState: LanguagePackState?
    private(set) var packNote: SettingsNote?
    private(set) var isDownloadingPack = false
    private(set) var packConfiguration: TranslationSession.Configuration?

    /// Brings the settings window forward: the download dialog needs an active key window.
    @ObservationIgnored var activateWindow: () -> Void = {}
    @ObservationIgnored private let keyStore: YandexKeyStore
    @ObservationIgnored private let keyCheck: YandexKeyCheck
    @ObservationIgnored private let pasteboard: SystemPasteboard
    @ObservationIgnored private let textTranslator: any TextTranslator
    @ObservationIgnored private var checkTask: Task<Void, Never>?

    init(
        keyStore: YandexKeyStore,
        keyCheck: YandexKeyCheck,
        pasteboard: SystemPasteboard,
        textTranslator: any TextTranslator
    ) {
        self.keyStore = keyStore
        self.keyCheck = keyCheck
        self.pasteboard = pasteboard
        self.textTranslator = textTranslator
    }

    /// Reloads everything the window shows, including the stored key.
    func reload() {
        loadKey()
        refreshStatuses()
    }

    /// Refreshes what the user may have changed in System Settings meanwhile.
    func refreshStatuses() {
        refreshLaunchState()
        pasteAccess = pasteboard.accessBehavior
        Task {
            await refreshPackState()
        }
    }

    func saveKey() {
        let key = keyDraft
        Task {
            do {
                try await keyStore.save(key)
            } catch {
                keyNote = .failure("Не удалось сохранить ключ в Связку ключей")
                return
            }
            let saved = key.trimmingCharacters(in: .whitespacesAndNewlines)
            keyDraft = saved
            keyNote = .success(saved.isEmpty ? "Ключ удалён" : "Ключ сохранён")
        }
    }

    func checkKey() {
        checkTask?.cancel()
        let key = keyDraft
        keyNote = nil
        isCheckingKey = true
        checkTask = Task {
            let note: SettingsNote
            do {
                try await keyCheck.check(key)
                note = .success("Ключ действителен")
            } catch let error as ProviderError {
                note = .failure(error.message)
            } catch {
                return
            }
            // a newer check or a reload has taken over
            guard !Task.isCancelled else {
                return
            }
            keyNote = note
            isCheckingKey = false
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

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Triggers the view's `.translationTask`, which shows the system download dialog.
    func downloadPack() {
        activateWindow()
        packNote = nil
        isDownloadingPack = true
        if packConfiguration == nil {
            packConfiguration = TranslationSession.Configuration(
                source: Language.en.locale,
                target: Language.ru.locale
            )
        } else {
            packConfiguration?.invalidate()
        }
    }

    func packDownloadFinished(failure: String?) async {
        isDownloadingPack = false
        if let failure {
            packNote = .failure("Пакет не скачан: \(failure)")
        }
        await refreshPackState()
    }

    private func loadKey() {
        checkTask?.cancel()
        isCheckingKey = false
        keyNote = nil
        do {
            keyDraft = try keyStore.load()
        } catch {
            keyDraft = ""
            keyNote = .failure("Не удалось прочитать ключ из Связки ключей")
        }
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
