import AppKit
import GlossCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: AppIdentity.bundleID, category: "app")
    private var environment: AppEnvironment?
    private var statusItem: StatusItemController?
    private var panel: PanelController?
    private var settingsWindow: SettingsWindowController?
    private var screenTextHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = MainMenu.make()
        let environment = AppEnvironment()
        self.environment = environment
        let panel = PanelController(
            settings: environment.settings,
            translator: environment.translator,
            pasteboard: environment.pasteboard,
            watcher: environment.watcher,
            onErrorAction: { [weak self] action in
                self?.perform(action)
            }
        )
        self.panel = panel

        environment.watcher.onDoubleCopy = { [weak panel] text in
            panel?.showTranslation(of: text)
        }
        // with paste access denied the copy is invisible: show the panel with the hint
        environment.watcher.onUnreadableCopy = { [weak panel, weak environment] in
            guard environment?.pasteboard.isAccessDenied == true else {
                return
            }
            panel?.showManualInput()
        }
        statusItem = StatusItemController(
            settings: environment.settings,
            onManualInput: { [weak panel] in
                panel?.showManualInput()
            },
            onReadScreenText: { [weak self] in
                self?.readScreenText()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
        environment.settings.observeDoubleCopy { [weak self] in
            self?.applyDoubleCopySettings()
        }
        applyDoubleCopySettings()
        screenTextHotKey = GlobalHotKey { [weak self] in
            self?.readScreenText()
        }
        environment.settings.observeScreenTextHotKey { [weak self] in
            self?.applyScreenTextHotKey()
        }
        applyScreenTextHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.watcher.stop()
    }

    // the popup floats above other windows: it would cover the settings
    private func openSettings() {
        panel?.dismissPopup()
        settingsWindowController()?.show()
    }

    private func perform(_ action: ErrorAction) {
        switch action {
        case .openSettings:
            openSettings()
        case .downloadLanguagePack:
            panel?.dismissPopup()
            settingsWindowController()?.showAndDownloadLanguagePack()
        case .allowPasteboardAccess:
            SystemSettingsLink.pasteAccess.open()
        case .allowScreenRecording:
            panel?.dismissPopup()
            SystemSettingsLink.screenRecording.open()
        }
    }

    /// Lets the user select a screen area and translates the text found in it.
    private func readScreenText() {
        guard let environment, let panel else {
            return
        }
        let hidesPinned = panel.hideForScreenCapture()
        let revision = panel.inputRevision
        Task {
            let outcome = await environment.screenText.read()
            // a query from double Cmd+C or the field during the selection is newer
            guard panel.inputRevision == revision else {
                return
            }
            switch outcome {
            case .text(let text):
                panel.showTranslation(of: text)
            case .failed(let error):
                panel.showScreenTextFailure(error)
            case .cancelled:
                if hidesPinned {
                    panel.restoreAfterScreenCapture()
                }
            }
        }
    }

    private func applyScreenTextHotKey() {
        guard let environment, let screenTextHotKey else {
            return
        }
        let settings = environment.settings
        screenTextHotKey.combination = settings.screenTextHotKeyEnabled
            ? settings.screenTextHotKey
            : nil
        if screenTextHotKey.isTaken {
            let name = KeyNames.displayName(of: settings.screenTextHotKey)
            logger.warning("\(name, privacy: .public) is taken by another app: use the menu")
        }
    }

    // created on first use: the window reads the key from Keychain only when opened
    private func settingsWindowController() -> SettingsWindowController? {
        if let settingsWindow {
            return settingsWindow
        }
        guard let environment, let screenTextHotKey else {
            return nil
        }
        let model = SettingsModel(
            key: YandexKeySettings(store: environment.keyStore, keyCheck: environment.keyCheck),
            pasteboard: environment.pasteboard,
            screenCapture: environment.screenCapture,
            textTranslator: SystemTextTranslator()
        )
        let controller = SettingsWindowController(
            model: model,
            settings: environment.settings,
            screenTextHotKey: screenTextHotKey
        )
        settingsWindow = controller
        return controller
    }

    private func applyDoubleCopySettings() {
        guard let environment else {
            return
        }
        let settings = environment.settings
        let watcher = environment.watcher
        watcher.interval = settings.doubleCopyInterval
        guard settings.doubleCopyEnabled else {
            watcher.stop()
            return
        }
        watcher.start()
        if environment.pasteboard.isAccessDenied {
            logger.warning("""
                paste access denied: allow Gloss in Privacy & Security → Paste from Other Apps
                """)
        }
    }
}
