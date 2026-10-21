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
    private var clipboardHotKey: GlobalHotKey?

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
            onTranslateClipboard: { [weak self] in
                self?.translateClipboard()
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
        clipboardHotKey = GlobalHotKey { [weak self] in
            self?.translateClipboard()
        }
        environment.settings.observeHotKeys { [weak self] in
            self?.applyHotKeys()
        }
        applyHotKeys()
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

    /// Translates the text on the pasteboard: for apps where double Cmd+C does not
    /// change the pasteboard twice, such as a terminal that copies a mouse selection itself.
    private func translateClipboard() {
        guard let environment, let panel else {
            return
        }
        switch environment.pasteboard.copiedText() {
        case .text(let text):
            panel.showTranslation(of: text)
        case .unreadable, .empty:
            // the panel shows the paste access hint when access is denied
            panel.showManualInput()
        }
    }

    private func applyHotKeys() {
        guard let environment, let screenTextHotKey, let clipboardHotKey else {
            return
        }
        let settings = environment.settings
        let screenText = settings.screenTextHotKeyEnabled ? settings.screenTextHotKey : nil
        let clipboard = settings.clipboardHotKeyEnabled ? settings.clipboardHotKey : nil
        apply(screenText, to: screenTextHotKey)
        apply(clipboard, to: clipboardHotKey)
    }

    private func apply(_ combination: HotKey?, to hotKey: GlobalHotKey) {
        hotKey.combination = combination
        if hotKey.isTaken, let combination {
            let name = KeyNames.displayName(of: combination)
            logger.warning("\(name, privacy: .public) is taken by another app: use the menu")
        }
    }

    // created on first use: the window reads the key from Keychain only when opened
    private func settingsWindowController() -> SettingsWindowController? {
        if let settingsWindow {
            return settingsWindow
        }
        guard let environment, let screenTextHotKey, let clipboardHotKey else {
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
            screenTextHotKey: screenTextHotKey,
            clipboardHotKey: clipboardHotKey
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
