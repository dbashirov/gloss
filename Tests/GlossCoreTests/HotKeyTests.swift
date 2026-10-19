import Testing
@testable import GlossCore

struct HotKeyTests {
    @Test(arguments: [
        HotKey.Modifiers.command,
        .option,
        .control,
        .shift,
        [.shift, .command],
        [.shift, .option],
        [.control, .option],
        [.control, .option, .shift, .command],
    ] as [HotKey.Modifiers])
    func requiresTwoModifiersWithACommandKey(modifiers: HotKey.Modifiers) {
        let hotKey = HotKey(keyCode: 0x08, modifiers: modifiers)
        let count = [HotKey.Modifiers.control, .option, .shift, .command]
            .filter { modifiers.contains($0) }
            .count

        #expect(hotKey.isAllowed == (count >= 2))
    }

    @Test func rejectsKeyWithoutModifiers() {
        #expect(!HotKey(keyCode: 0x08, modifiers: []).isAllowed)
    }

    @Test func rejectsShiftOnly() {
        #expect(!HotKey(keyCode: 0x08, modifiers: .shift).isAllowed)
    }

    @Test(arguments: [HotKey.Modifiers(), .shift, .command])
    func allowsFunctionKeyWithAnyModifiers(modifiers: HotKey.Modifiers) {
        let hotKey = HotKey(keyCode: 0x60, modifiers: modifiers)

        #expect(hotKey.isFunctionKey)
        #expect(hotKey.isAllowed)
    }

    @Test func defaultIsAllowed() {
        #expect(HotKey.screenTextDefault.isAllowed)
        #expect(HotKey.screenTextDefault.displayName(keyName: "2") == "⇧⌘2")
    }

    @Test func showsModifiersInMenuOrder() {
        let hotKey = HotKey(keyCode: 0x08, modifiers: [.command, .shift, .option, .control])

        #expect(hotKey.displayName(keyName: "c") == "⌃⌥⇧⌘C")
    }

    @Test(arguments: [
        (0x60, "F5"),
        (0x31, "Space"),
        (0x7B, "←"),
        (0x24, "↩"),
    ])
    func namesSpecialKeysItself(keyCode: Int, name: String) {
        let hotKey = HotKey(keyCode: keyCode, modifiers: [.control, .option])

        #expect(hotKey.specialKeyName == name)
        #expect(hotKey.displayName(keyName: "x") == "⌃⌥" + name)
    }

    @Test func showsKeyCodeWithoutKeyName() {
        let hotKey = HotKey(keyCode: 0x08, modifiers: [.control, .option])

        #expect(hotKey.specialKeyName == nil)
        #expect(hotKey.displayName(keyName: nil) == "⌃⌥#8")
    }
}
