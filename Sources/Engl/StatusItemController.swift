import AppKit
import EnglCore

/// StatusItemController owns the menu bar icon: a left click opens manual input,
/// a right click (or Control-click) shows the menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: AppSettings
    private let onManualInput: () -> Void
    private let onDoubleCopyToggle: () -> Void
    private let onOpenSettings: () -> Void

    init(
        settings: AppSettings,
        onManualInput: @escaping () -> Void,
        onDoubleCopyToggle: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.onManualInput = onManualInput
        self.onDoubleCopyToggle = onDoubleCopyToggle
        self.onOpenSettings = onOpenSettings
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }
        let image = NSImage(
            systemSymbolName: "character.book.closed",
            accessibilityDescription: "Engl"
        )
        image?.isTemplate = true
        button.image = image
        button.target = self
        button.action = #selector(buttonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }
        let isMenuClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isMenuClick {
            showMenu(from: sender)
        } else {
            onManualInput()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let doubleCopy = NSMenuItem(
            title: "Двойной Cmd+C",
            action: #selector(toggleDoubleCopy),
            keyEquivalent: ""
        )
        doubleCopy.state = settings.doubleCopyEnabled ? .on : .off
        menu.addItem(doubleCopy)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Настройки…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Выход",
            action: #selector(quit),
            keyEquivalent: "q"
        ))
        for item in menu.items {
            item.target = self
        }
        // a temporary menu anchors it under the icon; kept, it would swallow left clicks
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleDoubleCopy() {
        settings.doubleCopyEnabled.toggle()
        onDoubleCopyToggle()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
