import AppKit
import EnglCore
import SwiftUI

/// PanelController shows the translator panel either as a popup at the cursor, closed by
/// Esc, an outside click or another app's activation, or pinned at a saved position
/// and closed only by its close button or Cmd+W. The panel follows its content until
/// the user resizes it by an edge or the corner grip; that size is kept.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let autoWidth: CGFloat = 380
    static let autoMaxHeight: CGFloat = 480
    static let minSize = CGSize(width: 300, height: 160)

    private let panel = TranslatorPanel()
    private let settings: AppSettings
    private let translator: TranslationController
    private let pasteboard: SystemPasteboard
    private let watcher: ClipboardWatcher
    private let onErrorAction: (ErrorAction) -> Void
    private let model = PanelModel()
    private let speech = Speech()
    private lazy var hostingView = PanelHostingView(rootView: TranslatorView(
        model: model,
        translator: translator,
        settings: settings,
        speech: speech,
        actions: PanelActions(
            togglePin: { [weak self] in self?.togglePin() },
            close: { [weak self] in self?.hide() },
            copy: { [weak self] text in self?.copy(text) },
            perform: { [weak self] action in self?.onErrorAction(action) },
            resize: { [weak self] phase in self?.resizeByGrip(phase) },
            resetSize: { [weak self] in self?.resetSize() }
        )
    ))

    private var clickMonitor: Any?
    private var ownClickMonitor: Any?
    private var activationObserver: (any NSObjectProtocol)?
    /// The cursor the popup is anchored to; `nil` once the user moved the panel.
    private var popupCursor: CGPoint?
    private var placedFrame: CGRect?
    private var isResizeScheduled = false
    /// The panel frame and the screen cursor when the grip drag began.
    private var gripStart: (frame: CGRect, cursor: CGPoint)?

    init(
        settings: AppSettings,
        translator: TranslationController,
        pasteboard: SystemPasteboard,
        watcher: ClipboardWatcher,
        onErrorAction: @escaping (ErrorAction) -> Void
    ) {
        self.settings = settings
        self.translator = translator
        self.pasteboard = pasteboard
        self.watcher = watcher
        self.onErrorAction = onErrorAction
        super.init()
        updateSizingOptions()
        hostingView.onContentSizeChange = { [weak self] in
            self?.scheduleResize()
        }
        panel.contentView = hostingView
        panel.minSize = Self.minSize
        panel.delegate = self
        panel.onCancel = { [weak self] in
            self?.dismissPopup()
        }
        panel.onClose = { [weak self] in
            self?.hide()
        }
    }

    /// Starts translating the text and shows the panel with it as the query.
    func showTranslation(of text: String) {
        translator.translate(text)
        // the raw copy may be megabytes with line breaks: the field gets what is translated
        model.query = TextNormalizer.normalize(text) ?? ""
        show()
    }

    /// Shows the panel with an empty query field.
    func showManualInput() {
        translator.reset()
        model.query = ""
        show()
    }

    // only a drag by the user moves the saved position: own placements may be clamped
    func windowDidMove(_ notification: Notification) {
        if let placedFrame, PopupGeometry.isSamePosition(panel.frame.origin, placedFrame.origin) {
            return
        }
        popupCursor = nil
        if settings.isPinned {
            savePinnedPosition()
        }
    }

    // a drag of a panel edge switches the panel to the size chosen by the user
    func windowWillStartLiveResize(_ notification: Notification) {
        popupCursor = nil
        settings.panelSize = panel.frame.size
        updateSizingOptions()
    }

    func windowDidResize(_ notification: Notification) {
        guard panel.inLiveResize else {
            return
        }
        settings.panelSize = panel.frame.size
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        settings.panelSize = panel.frame.size
        if settings.isPinned {
            savePinnedPosition()
        }
    }

    /// Hides the popup; a pinned panel stays until its close button or Cmd+W.
    func dismissPopup() {
        guard !settings.isPinned else {
            return
        }
        hide()
    }

    private func hide() {
        removeMonitors()
        panel.orderOut(nil)
        popupCursor = nil
    }

    private func togglePin() {
        settings.isPinned.toggle()
        if settings.isPinned {
            savePinnedPosition()
        }
        updateMonitors()
    }

    private func resizeByGrip(_ phase: PanelResizePhase) {
        guard phase == .changed else {
            gripStart = nil
            return
        }
        let cursor = NSEvent.mouseLocation
        if gripStart == nil {
            gripStart = (panel.frame, cursor)
            popupCursor = nil
        }
        guard let gripStart,
              let visibleFrame = visibleFrame(near: PopupGeometry.topLeft(of: gripStart.frame))
        else {
            return
        }
        let frame = PopupGeometry.resizedFrame(
            gripStart.frame,
            dragStart: gripStart.cursor,
            dragCurrent: cursor,
            minSize: Self.minSize,
            visibleFrame: visibleFrame
        )
        settings.panelSize = frame.size
        updateSizingOptions()
        place(frame)
    }

    private func resetSize() {
        settings.panelSize = nil
        updateSizingOptions()
        scheduleResize()
    }

    // the content's own size would fight a size chosen by the user
    private func updateSizingOptions() {
        let options: NSHostingSizingOptions = settings.panelSize == nil
            ? [.intrinsicContentSize]
            : []
        if hostingView.sizingOptions != options {
            hostingView.sizingOptions = options
        }
    }

    private func savePinnedPosition() {
        settings.pinnedTopLeft = PopupGeometry.topLeft(of: panel.frame)
    }

    /// Writes the app's own copy: neither a copy for the watcher nor kept by clipboard managers.
    private func copy(_ text: String) {
        guard !text.isEmpty else {
            return
        }
        watcher.ignore(changeCount: pasteboard.write(text))
    }

    private func show() {
        model.isPasteAccessDenied = pasteboard.isAccessDenied
        let size = contentSize()
        let origin = savedOrigin(for: size) ?? popupOrigin(for: size)
        place(CGRect(origin: origin, size: size))
        panel.makeKeyAndOrderFront(nil)
        model.focusRequest += 1
        updateMonitors()
    }

    private func savedOrigin(for size: CGSize) -> CGPoint? {
        guard settings.isPinned, let topLeft = settings.pinnedTopLeft else {
            return nil
        }
        popupCursor = nil
        // the monitor the panel was pinned on may be gone
        return PopupGeometry.origin(
            topLeft: topLeft,
            size: size,
            visibleFrame: visibleFrame(near: topLeft)
        )
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
        if let panelSize = settings.panelSize {
            let screen = visibleFrame(near: settings.pinnedTopLeft ?? NSEvent.mouseLocation)
            guard let screen else {
                return panelSize
            }
            return PopupGeometry.fit(size: panelSize, minSize: Self.minSize, visibleFrame: screen)
        }
        let fitting = hostingView.fittingSize
        return CGSize(width: Self.autoWidth, height: min(fitting.height, Self.autoMaxHeight))
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
        guard panel.isVisible, settings.panelSize == nil else {
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
        if ownClickMonitor == nil {
            // the app's own windows, e.g. the settings, are not seen by the global monitor
            ownClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    if let self, event.window !== self.panel {
                        self.hide()
                    }
                }
                return event
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
        if let ownClickMonitor {
            NSEvent.removeMonitor(ownClickMonitor)
            self.ownClickMonitor = nil
        }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }
}
