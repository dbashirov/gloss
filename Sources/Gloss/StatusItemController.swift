import AppKit
import GlossCore

/// StatusItemController owns the menu bar icon: a left click opens manual input,
/// a right click (or Control-click) shows the menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: AppSettings
    private let onManualInput: () -> Void
    private let onReadScreenText: () -> Void
    private let onTranslateClipboard: () -> Void
    private let onOpenSettings: () -> Void

    init(
        settings: AppSettings,
        onManualInput: @escaping () -> Void,
        onReadScreenText: @escaping () -> Void,
        onTranslateClipboard: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.onManualInput = onManualInput
        self.onReadScreenText = onReadScreenText
        self.onTranslateClipboard = onTranslateClipboard
        self.onOpenSettings = onOpenSettings
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }
        // the bundled icon is missing when the binary runs outside Gloss.app
        let image = NSImage(named: "StatusIcon")
            ?? NSImage(systemSymbolName: "translate", accessibilityDescription: "Gloss")
        image?.isTemplate = true
        image?.accessibilityDescription = "Gloss"
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
        menu.addItem(hotKeyItem(
            title: "Перевести текст с экрана",
            action: #selector(readScreenText),
            hotKey: settings.screenTextHotKeyEnabled ? settings.screenTextHotKey : nil
        ))
        menu.addItem(hotKeyItem(
            title: "Перевести скопированный текст",
            action: #selector(translateClipboard),
            hotKey: settings.clipboardHotKeyEnabled ? settings.clipboardHotKey : nil
        ))
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

    private func hotKeyItem(title: String, action: Selector, hotKey: HotKey?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        if let hotKey, let key = KeyNames.keyEquivalent(of: hotKey) {
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = KeyNames.modifierMask(of: hotKey)
        }
        return item
    }

    @objc private func toggleDoubleCopy() {
        settings.doubleCopyEnabled.toggle()
    }

    @objc private func readScreenText() {
        onReadScreenText()
    }

    @objc private func translateClipboard() {
        onTranslateClipboard()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
