/// HotKey is a global key combination: a virtual key code (`kVK_` in Carbon) and modifiers.
public struct HotKey: Equatable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)

        /// The modifiers that make a key a command rather than typing.
        static let commandKeys: Modifiers = [.control, .option, .command]
    }

    /// ⌘⇧2: the key code of 2 on the ANSI layout.
    public static let screenTextDefault = HotKey(keyCode: 0x13, modifiers: [.command, .shift])
    /// ⌘⇧1: the key code of 1 on the ANSI layout.
    public static let clipboardDefault = HotKey(keyCode: 0x12, modifiers: [.command, .shift])

    private static let functionKeyNames: [Int: String] = [
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x69: "F13", 0x6B: "F14", 0x71: "F15", 0x6A: "F16", 0x40: "F17", 0x4F: "F18",
        0x50: "F19", 0x5A: "F20",
    ]

    private static let specialKeyNames: [Int: String] = [
        0x31: "Space", 0x24: "↩", 0x4C: "⌤", 0x30: "⇥", 0x33: "⌫", 0x75: "⌦", 0x35: "⎋",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x73: "↖", 0x77: "↘", 0x74: "⇞", 0x79: "⇟",
    ]

    public let keyCode: Int
    public let modifiers: Modifiers

    public init(keyCode: Int, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var isFunctionKey: Bool {
        Self.functionKeyNames[keyCode] != nil
    }

    // a single ⌘ or ⌥ would take app commands (⌘C) or typing (⌥E): two modifiers are needed
    public var isAllowed: Bool {
        if isFunctionKey {
            return true
        }
        let count = [Modifiers.control, .option, .shift, .command]
            .filter { modifiers.contains($0) }
            .count
        return count >= 2 && !modifiers.isDisjoint(with: Modifiers.commandKeys)
    }

    /// Returns the name of a key that types no character (F5, ←, Space), `nil` for others.
    public var specialKeyName: String? {
        Self.functionKeyNames[keyCode] ?? Self.specialKeyNames[keyCode]
    }

    /// Returns the combination as macOS menus show it: ⌃⌥⇧⌘ and then the key.
    /// `keyName` names a character key on the current layout.
    public func displayName(keyName: String?) -> String {
        let symbols: [(Modifiers, String)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]
        let prefix = symbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
        let key = specialKeyName ?? keyName?.uppercased() ?? "#\(keyCode)"
        return prefix + key
    }
}
