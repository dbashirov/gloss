import AppKit
import EnglCore

/// SystemPasteboard adapts `NSPasteboard.general` to `PasteboardReading`.
@MainActor
final class SystemPasteboard: PasteboardReading {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    var types: [String] {
        pasteboard.types?.map(\.rawValue) ?? []
    }

    /// `.alwaysDeny` means the user turned off paste access in Privacy & Security.
    var accessBehavior: NSPasteboard.AccessBehavior {
        pasteboard.accessBehavior
    }

    func string() -> String? {
        pasteboard.string(forType: .string)
    }
}
