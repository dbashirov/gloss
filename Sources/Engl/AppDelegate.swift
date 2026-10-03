import AppKit
import EnglCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.dbashirov.engl", category: "app")
    private var environment: AppEnvironment?
    private var statusItem: StatusItemController?
    private var panel: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        logger.info("settings requested")
    }

    // the settings window (Task 13) takes over open settings and the pack download
    private func perform(_ action: ErrorAction) {
        switch action {
        case .openSettings:
            openSettings()
        case .downloadLanguagePack:
            SystemSettingsLink.translationLanguages.open()
        case .allowPasteboardAccess:
            SystemSettingsLink.pasteAccess.open()
        }
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
