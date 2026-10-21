import AppKit
import GlossCore
import SwiftUI

/// SettingsWindowController owns the settings window. Showing it activates the
/// accessory app so the window becomes key, as the language pack download requires.
@MainActor
final class SettingsWindowController: NSObject {
    private let model: SettingsModel
    private let window: NSWindow
    private var activationObserver: (any NSObjectProtocol)?
    private var screenObservers: [any NSObjectProtocol] = []

    init(
        model: SettingsModel,
        settings: AppSettings,
        screenTextHotKey: GlobalHotKey,
        clipboardHotKey: GlobalHotKey
    ) {
        self.model = model
        let content = NSHostingController(rootView: SettingsView(
            model: model,
            settings: settings,
            screenTextHotKey: screenTextHotKey,
            clipboardHotKey: clipboardHotKey
        ))
        window = NSWindow(contentViewController: content)
        window.title = "Настройки Gloss"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        super.init()
        model.activateWindow = { [weak self] in
            self?.activate()
        }
        // the user may come back from System Settings with a new paste access or pack
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshIfVisible()
            }
        }
        // the window moved to another screen, or displays were attached or removed
        let screenChanges = [
            (NSWindow.didChangeScreenNotification, window as NSObject?),
            (NSApplication.didChangeScreenParametersNotification, nil),
        ]
        let center = NotificationCenter.default
        screenObservers = screenChanges.map { name, object in
            center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.fitVisibleWindow()
                }
            }
        }
    }

    func show() {
        if !window.isVisible {
            model.reload()
            fitHeight(to: NSScreen.main)
            // a hidden hosting window gets its size only when shown: center() needs it now
            window.setContentSize(window.contentViewController?.view.fittingSize ?? .zero)
            window.center()
        }
        activate()
    }

    /// Shows the window and starts the en↔ru pack download right away.
    func showAndDownloadLanguagePack() {
        show()
        model.downloadPack()
    }

    private func activate() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    // the form scrolls: the window must not go past the edge of a low screen
    private func fitHeight(to screen: NSScreen?) {
        guard let screen else {
            return
        }
        model.formHeight = min(SettingsModel.preferredFormHeight, screen.visibleFrame.height - 40)
    }

    private func fitVisibleWindow() {
        guard window.isVisible else {
            return
        }
        fitHeight(to: window.screen)
    }

    private func refreshIfVisible() {
        guard window.isVisible else {
            return
        }
        model.refreshStatuses()
    }
}
