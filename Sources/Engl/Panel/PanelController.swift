import AppKit
import EnglCore

/// PanelController shows the translator panel either as a popup at the cursor, closed by
/// Esc, an outside click or another app's activation, or pinned at a saved position.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let width: CGFloat = 380
    static let maxHeight: CGFloat = 480

    private let panel = TranslatorPanel()
    private let settings: AppSettings
    private let translator: TranslationController
    private let model = PanelModel()
    private lazy var hostingView = PanelHostingView(rootView: PanelPlaceholderView(
        model: model,
        translator: translator,
        settings: settings,
        onTogglePin: { [weak self] in self?.togglePin() }
    ))

    private var clickMonitor: Any?
    private var activationObserver: (any NSObjectProtocol)?
    /// The cursor the popup is anchored to; `nil` once the user moved the panel.
    private var popupCursor: CGPoint?
    private var placedFrame: CGRect?
    private var isResizeScheduled = false

    init(settings: AppSettings, translator: TranslationController) {
        self.settings = settings
        self.translator = translator
        super.init()
        hostingView.sizingOptions = [.intrinsicContentSize]
        hostingView.onContentSizeChange = { [weak self] in
            self?.scheduleResize()
        }
        panel.contentView = hostingView
        panel.delegate = self
        panel.onCancel = { [weak self] in
            self?.hide()
        }
    }

    /// Starts translating the text and shows the panel with it as the query.
    func showTranslation(of text: String) {
        translator.translate(text)
        model.query = text
        show()
    }

    /// Shows the panel with an empty query field.
    func showManualInput() {
        translator.reset()
        model.query = ""
        show()
    }

    func hide() {
        removeMonitors()
        panel.orderOut(nil)
        popupCursor = nil
    }

    func togglePin() {
        settings.isPinned.toggle()
        if settings.isPinned {
            settings.pinnedOrigin = panel.frame.origin
        }
        updateMonitors()
    }

    func windowDidMove(_ notification: Notification) {
        let isOwnPlacement = panel.frame.origin == placedFrame?.origin
        if !isOwnPlacement {
            popupCursor = nil
        }
        if settings.isPinned {
            settings.pinnedOrigin = panel.frame.origin
        }
    }

    private func show() {
        let size = contentSize()
        let origin = savedOrigin(for: size) ?? popupOrigin(for: size)
        place(CGRect(origin: origin, size: size))
        panel.makeKeyAndOrderFront(nil)
        model.focusRequest += 1
        updateMonitors()
    }

    private func savedOrigin(for size: CGSize) -> CGPoint? {
        guard settings.isPinned, let saved = settings.pinnedOrigin else {
            return nil
        }
        popupCursor = nil
        // the monitor the panel was pinned on may be gone
        guard let visibleFrame = visibleFrame(near: saved) else {
            return saved
        }
        return PopupGeometry.clamp(origin: saved, size: size, visibleFrame: visibleFrame)
    }

    private func popupOrigin(for size: CGSize) -> CGPoint {
        let cursor = NSEvent.mouseLocation
        popupCursor = cursor
        guard let visibleFrame = visibleFrame(near: cursor) else {
            return cursor
        }
        return PopupGeometry.origin(cursor: cursor, size: size, visibleFrame: visibleFrame)
    }

    private func contentSize() -> CGSize {
        let fitting = hostingView.fittingSize
        return CGSize(width: Self.width, height: min(fitting.height, Self.maxHeight))
    }

    private func place(_ frame: CGRect) {
        placedFrame = frame
        panel.setFrame(frame, display: true)
    }

    private func visibleFrame(near point: CGPoint) -> CGRect? {
        let screens = NSScreen.screens
        let frames = screens.map(\.frame)
        guard let index = PopupGeometry.nearestFrameIndex(to: point, in: frames) else {
            return nil
        }
        return screens[index].visibleFrame
    }

    // the content reports a new size in the middle of a layout pass: resize after it
    private func scheduleResize() {
        guard !isResizeScheduled else {
            return
        }
        isResizeScheduled = true
        Task { [weak self] in
            self?.fitContent()
        }
    }

    private func fitContent() {
        isResizeScheduled = false
        guard panel.isVisible else {
            return
        }
        let size = contentSize()
        let current = panel.frame
        let center = CGPoint(x: current.midX, y: current.midY)
        guard let visibleFrame = visibleFrame(near: popupCursor ?? center) else {
            return
        }
        let origin = if let popupCursor, !settings.isPinned {
            PopupGeometry.origin(cursor: popupCursor, size: size, visibleFrame: visibleFrame)
        } else {
            PopupGeometry.resized(frame: current, to: size, visibleFrame: visibleFrame)
        }
        let frame = CGRect(origin: origin, size: size)
        guard frame != current else {
            return
        }
        place(frame)
    }

    private func updateMonitors() {
        if panel.isVisible && !settings.isPinned {
            installMonitors()
        } else {
            removeMonitors()
        }
    }

    private func installMonitors() {
        if clickMonitor == nil {
            // a global monitor sees only events sent to other apps: any click is outside
            clickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.hide()
                }
            }
        }
        if activationObserver == nil {
            let ownPID = ProcessInfo.processInfo.processIdentifier
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let key = NSWorkspace.applicationUserInfoKey
                let app = notification.userInfo?[key] as? NSRunningApplication
                guard app?.processIdentifier != ownPID else {
                    return
                }
                MainActor.assumeIsolated {
                    self?.hide()
                }
            }
        }
    }

    private func removeMonitors() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }
}
