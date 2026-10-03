import AppKit
import EnglCore

/// SystemPasteboard adapts `NSPasteboard.general` to `PasteboardReading`.
@MainActor
final class SystemPasteboard: PasteboardReading {
    private let pasteboard = NSPasteboard.general

    var changeCount: Int {
        pasteboard.changeCount
    }

    var types: [String] {
        pasteboard.types?.map(\.rawValue) ?? []
    }

    var access: PasteAccess {
        switch pasteboard.accessBehavior {
        case .alwaysAllow:
            .allowed
        case .alwaysDeny:
            .denied
        default:
            .ask
        }
    }

    /// Tells whether the user turned off paste access in Privacy & Security.
    var isAccessDenied: Bool {
        access == .denied
    }

    func string() -> String? {
        pasteboard.string(forType: .string)
    }

    /// Writes text marked as transient so clipboard managers skip it; returns the new
    /// `changeCount` for `ClipboardWatcher.ignore(changeCount:)`.
    func write(_ text: String) -> Int {
        let transient = NSPasteboard.PasteboardType(PasteboardType.transient)
        pasteboard.declareTypes([.string, transient], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: transient)
        return pasteboard.changeCount
    }
}
