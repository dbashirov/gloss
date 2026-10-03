import AppKit
import EnglCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.dbashirov.engl", category: "app")
    private var environment: AppEnvironment?
    private var statusItem: StatusItemController?
    private var panel: PanelController?
    private var settingsWindow: SettingsWindowController?

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
        statusItem = StatusItemController(
            settings: environment.settings,
            onManualInput: { [weak panel] in
                panel?.showManualInput()
            },
            onDoubleCopyToggle: { [weak self] in
                self?.applyDoubleCopySettings()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
        applyDoubleCopySettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.watcher.stop()
    }

    private func openSettings() {
        settingsWindowController()?.show()
    }

    private func perform(_ action: ErrorAction) {
        switch action {
        case .openSettings:
            panel?.dismissPopup()
            openSettings()
        case .downloadLanguagePack:
            panel?.dismissPopup()
            settingsWindowController()?.showAndDownloadLanguagePack()
        case .allowPasteboardAccess:
            SystemSettingsLink.pasteAccess.open()
        }
    }

    // created on first use: the window reads the key from Keychain only when opened
    private func settingsWindowController() -> SettingsWindowController? {
        if let settingsWindow {
            return settingsWindow
        }
        guard let environment else {
            return nil
        }
        let model = SettingsModel(
            keyStore: environment.keyStore,
            keyCheck: environment.keyCheck,
            pasteboard: environment.pasteboard,
            textTranslator: SystemTextTranslator()
        )
        let controller = SettingsWindowController(
            model: model,
            settings: environment.settings,
            onDoubleCopyChange: { [weak self] in
                self?.applyDoubleCopySettings()
            }
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
        watcher.interval = .seconds(settings.doubleCopyInterval)
        guard settings.doubleCopyEnabled else {
            watcher.stop()
            return
        }
        watcher.start()
        if environment.pasteboard.accessBehavior == .alwaysDeny {
            logger.warning("""
                paste access denied: allow Engl in Privacy & Security → Paste from Other Apps
                """)
        }
    }
}
