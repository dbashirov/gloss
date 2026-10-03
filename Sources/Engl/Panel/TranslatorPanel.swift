import AppKit

/// TranslatorPanel is a floating panel that takes key focus without activating the app,
/// like Spotlight: the query can be edited right away while another app stays active.
final class TranslatorPanel: NSPanel {
    private static let escapeKeyCode: UInt16 = 53

    /// Called on Esc.
    var onCancel: (() -> Void)?
    /// Called on Cmd+W.
    var onClose: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
    }

    // a borderless window refuses key status by default
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    // the focused query field would take Esc for word completion before cancelOperation
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == Self.escapeKeyCode, !isComposingText {
            onCancel?()
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    // a window without a close button only beeps on performClose
    override func performClose(_ sender: Any?) {
        onClose?()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(performClose(_:)) {
            return true
        }
        return super.validateMenuItem(menuItem)
    }

    // Esc first cancels an input method composition
    private var isComposingText: Bool {
        (firstResponder as? NSTextView)?.hasMarkedText() ?? false
    }
}
