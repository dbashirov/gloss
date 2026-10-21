import AppKit
import GlossCore
import SwiftUI

/// SettingsWindowController owns the settings window: a toolbar of tabs over the page of
/// the selected one. Showing it activates the accessory app so the window becomes key,
/// as the language pack download requires.
@MainActor
final class SettingsWindowController: NSObject, NSToolbarDelegate {
    private let model: SettingsModel
    private let window: NSWindow
    private var activationObserver: (any NSObjectProtocol)?

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
        // the window takes the height of each page and keeps its top edge
        content.sizingOptions = [.preferredContentSize]
        window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init()
        let toolbar = NSToolbar(identifier: "settings")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        window.toolbar = toolbar
        select(model.tab)
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
            // a hidden hosting window gets its size only when shown: center() needs it now
            window.setContentSize(window.contentViewController?.view.fittingSize ?? .zero)
            window.center()
        }
        activate()
    }

    /// Shows the translation page and starts the en↔ru pack download right away.
    func showAndDownloadLanguagePack() {
        select(.translation)
        show()
        model.downloadPack()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(\.itemIdentifier)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(\.itemIdentifier)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(\.itemIdentifier)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else {
            return nil
        }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(tabClicked(_:))
        return item
    }

    @objc private func tabClicked(_ item: NSToolbarItem) {
        guard let tab = SettingsTab(rawValue: item.itemIdentifier.rawValue) else {
            return
        }
        select(tab)
    }

    // macOS settings windows are titled after the selected tab
    private func select(_ tab: SettingsTab) {
        model.tab = tab
        window.toolbar?.selectedItemIdentifier = tab.itemIdentifier
        window.title = tab.title
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

private extension SettingsTab {
    var itemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(rawValue)
    }
}
