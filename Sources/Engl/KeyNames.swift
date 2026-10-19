import AppKit
import Carbon.HIToolbox
import EnglCore

/// KeyNames names hot keys by the current ASCII-capable layout: a Russian layout
/// still shows ⌃⌥C, not ⌃⌥С.
@MainActor
enum KeyNames {
    private static let menuKeys: [Int: Int] = [
        kVK_Space: 0x20, kVK_Return: 0x0D, kVK_ANSI_KeypadEnter: 0x03, kVK_Tab: 0x09,
        kVK_Delete: 0x08, kVK_ForwardDelete: NSDeleteFunctionKey, kVK_Escape: 0x1B,
        kVK_LeftArrow: NSLeftArrowFunctionKey, kVK_RightArrow: NSRightArrowFunctionKey,
        kVK_DownArrow: NSDownArrowFunctionKey, kVK_UpArrow: NSUpArrowFunctionKey,
        kVK_Home: NSHomeFunctionKey, kVK_End: NSEndFunctionKey,
        kVK_PageUp: NSPageUpFunctionKey, kVK_PageDown: NSPageDownFunctionKey,
    ]

    static func displayName(of hotKey: HotKey) -> String {
        hotKey.displayName(keyName: character(for: hotKey.keyCode))
    }

    /// Returns the menu item key equivalent of the combination, `nil` for an unknown key.
    static func keyEquivalent(of hotKey: HotKey) -> String? {
        if hotKey.isFunctionKey, let number = hotKey.specialKeyName.flatMap({ Int($0.dropFirst()) }) {
            return String(utf16CodeUnits: [UniChar(NSF1FunctionKey + number - 1)], count: 1)
        }
        if let key = menuKeys[hotKey.keyCode] {
            return String(utf16CodeUnits: [UniChar(key)], count: 1)
        }
        return character(for: hotKey.keyCode)
    }

    static func modifierMask(of hotKey: HotKey) -> NSEvent.ModifierFlags {
        let flags: [(HotKey.Modifiers, NSEvent.ModifierFlags)] = [
            (.control, .control), (.option, .option), (.shift, .shift), (.command, .command),
        ]
        return flags.reduce(into: []) { mask, flag in
            if hotKey.modifiers.contains(flag.0) {
                mask.insert(flag.1)
            }
        }
    }

    /// Returns the character the key types without modifiers, e.g. "2" for `kVK_ANSI_2`.
    static func character(for keyCode: Int) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
            .takeRetainedValue(),
            let layout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(layout).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { buffer in
            UCKeyTranslate(
                buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self),
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else {
            return nil
        }
        let character = String(utf16CodeUnits: characters, count: length)
        return character.allSatisfy(\.isWhitespace) ? nil : character
    }
}

extension HotKey.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) {
            insert(.control)
        }
        if flags.contains(.option) {
            insert(.option)
        }
        if flags.contains(.shift) {
            insert(.shift)
        }
        if flags.contains(.command) {
            insert(.command)
        }
    }
}
