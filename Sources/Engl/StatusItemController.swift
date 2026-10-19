import AppKit
import EnglCore

/// StatusItemController owns the menu bar icon: a left click opens manual input,
/// a right click (or Control-click) shows the menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: AppSettings
    private let onManualInput: () -> Void
    private let onReadScreenText: () -> Void
    private let onOpenSettings: () -> Void

    init(
        settings: AppSettings,
        onManualInput: @escaping () -> Void,
        onReadScreenText: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.onManualInput = onManualInput
        self.onReadScreenText = onReadScreenText
        self.onOpenSettings = onOpenSettings
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }
        // the bundled icon is missing when the binary runs outside Engl.app
        let image = NSImage(named: "StatusIcon")
            ?? NSImage(systemSymbolName: "translate", accessibilityDescription: "Engl")
        image?.isTemplate = true
        image?.accessibilityDescription = "Engl"
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
        let screenText = NSMenuItem(
            title: "Перевести текст с экрана",
            action: #selector(readScreenText),
            keyEquivalent: ""
        )
        let hotKey = settings.screenTextHotKey
        if settings.screenTextHotKeyEnabled, let key = KeyNames.keyEquivalent(of: hotKey) {
            screenText.keyEquivalent = key
            screenText.keyEquivalentModifierMask = KeyNames.modifierMask(of: hotKey)
        }
        menu.addItem(screenText)
        menu.addItem(.separator())
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
    }

    @objc private func readScreenText() {
        onReadScreenText()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
