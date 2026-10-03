import AppKit

/// MainMenu is never shown in an accessory app, but without it text fields get no
/// Cmd+C, Cmd+V, Cmd+A and windows no Cmd+W.
enum MainMenu {
    @MainActor
    static func make() -> NSMenu {
        let app = NSMenu(title: "Engl")
        app.addItem(
            withTitle: "Закрыть окно",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )

        let edit = NSMenu(title: "Правка")
        edit.addItem(
            withTitle: "Отменить",
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        let redo = edit.addItem(
            withTitle: "Повторить",
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(
            withTitle: "Вырезать",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        edit.addItem(
            withTitle: "Копировать",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        edit.addItem(
            withTitle: "Вставить",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        edit.addItem(
            withTitle: "Выбрать все",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        let menu = NSMenu()
        for submenu in [app, edit] {
            let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            menu.addItem(item)
        }
        return menu
    }
}
