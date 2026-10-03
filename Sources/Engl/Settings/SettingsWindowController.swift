import AppKit
import EnglCore
import SwiftUI

/// SettingsWindowController owns the settings window. Showing it activates the
/// accessory app so the window becomes key, as the language pack download requires.
@MainActor
final class SettingsWindowController: NSObject {
    private let model: SettingsModel
    private let window: NSWindow
    private var activationObserver: (any NSObjectProtocol)?

    init(model: SettingsModel, settings: AppSettings, onDoubleCopyChange: @escaping () -> Void) {
        self.model = model
        let content = NSHostingController(rootView: SettingsView(
            model: model,
            settings: settings,
            onDoubleCopyChange: onDoubleCopyChange
        ))
        window = NSWindow(contentViewController: content)
        window.title = "Настройки Engl"
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
    }

    func show() {
        if !window.isVisible {
            model.reload()
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

    private func refreshIfVisible() {
        guard window.isVisible else {
            return
        }
        model.refreshStatuses()
    }
}
