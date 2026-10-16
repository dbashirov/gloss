import AppKit
import EnglCore
import SwiftUI

/// QueryField is the multiline query editor: 3 to 6 lines high, a longer text scrolls
/// with a scroller. Enter submits, ⌥Enter inserts a line break.
struct QueryField: View {
    @Binding var text: String
    /// Moves the focus into the field and selects its text on every change.
    let focusRequest: Int
    let onSubmit: () -> Void

    @Environment(\.typography) private var typography
    private let height = State(initialValue: CGFloat?.none)
    private let isFocused = State(initialValue: false)

    var body: some View {
        let font = typography.nsFont(size: typography.body)
        let shape = RoundedRectangle(cornerRadius: 6)
        QueryTextView(
            text: $text,
            font: font,
            focusRequest: focusRequest,
            onSubmit: onSubmit,
            onHeightChange: { height.wrappedValue = $0 },
            onFocusChange: { isFocused.wrappedValue = $0 }
        )
        .frame(height: height.wrappedValue ?? QueryTextView.height(lines: 3, font: font))
        .overlay(alignment: .topLeading) {
            if text.isEmpty {
                Text("Слово или фраза")
                    .foregroundStyle(.tertiary)
                    .padding(.leading, QueryTextView.textOrigin.x)
                    .padding(.top, QueryTextView.textOrigin.y)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(nsColor: .textBackgroundColor), in: shape)
        .clipShape(shape)
        .overlay {
            let isFocused = isFocused.wrappedValue
            shape.strokeBorder(
                isFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.4),
                lineWidth: isFocused ? 2 : 1
            )
        }
    }
}

// SwiftUI text fields have no scroller: the editor is an AppKit text view in a scroll view
private struct QueryTextView: NSViewRepresentable {
    static let minLines = 3
    static let maxLines = 6
    private static let inset = NSSize(width: 3, height: 4)

    @Binding var text: String
    let font: NSFont
    let focusRequest: Int
    let onSubmit: () -> Void
    let onHeightChange: (CGFloat) -> Void
    let onFocusChange: (Bool) -> Void

    /// Position of the first character inside the field, for the placeholder.
    static var textOrigin: CGPoint {
        CGPoint(x: inset.width + NSTextContainer().lineFragmentPadding, y: inset.height)
    }

    static func height(lines: Int, font: NSFont) -> CGFloat {
        NSLayoutManager().defaultLineHeight(for: font) * CGFloat(lines) + inset.height * 2
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> QueryScrollView {
        // TextKit 1: the layout manager gives the line height the field is measured in
        let textView = QueryTextEditor(usingTextLayoutManager: false)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = Self.inset
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = .zero
        let unlimited = CGFloat.greatestFiniteMagnitude
        textView.maxSize = NSSize(width: unlimited, height: unlimited)
        textView.textContainer?.widthTracksTextView = true
        textView.font = font
        textView.textColor = .textColor
        textView.string = text
        textView.toolTip = "Enter - перевести, ⌥Enter - новая строка"
        let coordinator = context.coordinator
        textView.delegate = coordinator
        textView.onFocusChange = { [weak coordinator] isFocused in
            coordinator?.parent.onFocusChange(isFocused)
        }

        let scrollView = QueryScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        // overlay scrollers show up only while scrolling: the text would look cut off
        scrollView.scrollerStyle = .legacy
        scrollView.documentView = textView
        coordinator.observe(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: QueryScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = scrollView.documentView as? QueryTextEditor else {
            return
        }
        if textView.font != font {
            textView.font = font
            coordinator.updateHeight()
        }
        // the binding stays behind the editor while an input method composes
        if text != coordinator.syncedText {
            coordinator.syncedText = text
            if textView.hasMarkedText() {
                // a composition left in place would be committed over the new query
                textView.inputContext?.discardMarkedText()
            }
            if textView.string != text {
                textView.string = text
                // undo steps of the typed text point at ranges the new text may not have
                coordinator.undoManager.removeAllActions()
                coordinator.updateHeight()
            }
        }
        if coordinator.focusRequest != focusRequest {
            coordinator.focusRequest = focusRequest
            // the request comes with the panel shown: focus once its window is in place
            Task { [weak textView] in
                guard let textView else {
                    return
                }
                textView.window?.makeFirstResponder(textView)
                textView.selectAll(nil)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QueryTextView
        var focusRequest = 0
        /// The query as the field last read or wrote it: another value comes from outside.
        var syncedText: String
        /// The field's own undo history, cleared when the query is replaced from outside.
        let undoManager = UndoManager()
        private weak var textView: NSTextView?
        private var reportedHeight: CGFloat?

        init(parent: QueryTextView) {
            self.parent = parent
            syncedText = parent.text
        }

        /// Follows the text view frame: a new width wraps the text into other lines.
        func observe(_ textView: NSTextView) {
            self.textView = textView
            textView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(textViewFrameDidChange),
                name: NSView.frameDidChangeNotification,
                object: textView
            )
            updateHeight()
        }

        func updateHeight() {
            guard let textView,
                  let font = textView.font,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer
            else {
                return
            }
            // the text view is never lower than the visible area: the text is measured
            layoutManager.ensureLayout(for: container)
            let textHeight = layoutManager.usedRect(for: container).height
                + textView.textContainerInset.height * 2
            let minHeight = QueryTextView.height(lines: QueryTextView.minLines, font: font)
            let maxHeight = QueryTextView.height(lines: QueryTextView.maxLines, font: font)
            let height = min(max(textHeight, minHeight), maxHeight)
            guard reportedHeight.map({ abs($0 - height) > 0.5 }) ?? true else {
                return
            }
            reportedHeight = height
            // the frame changes mid-layout: SwiftUI state is set on the next turn
            let onHeightChange = parent.onHeightChange
            Task {
                onHeightChange(height)
            }
        }

        func textDidChange(_ notification: Notification) {
            if let textView {
                syncedText = textView.string
                parent.text = textView.string
            }
            updateHeight()
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            undoManager
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // ⌥Enter sends insertNewlineIgnoringFieldEditor and inserts a line break
            guard selector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            parent.onSubmit()
            return true
        }

        @objc private func textViewFrameDidChange(_ notification: Notification) {
            updateHeight()
        }
    }
}

/// QueryTextEditor tells the field when it gains or loses the focus.
private final class QueryTextEditor: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onFocusChange?(true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            onFocusChange?(false)
        }
        return result
    }
}

/// QueryScrollView keeps its text view as wide as the visible area.
private final class QueryScrollView: NSScrollView {
    override func tile() {
        super.tile()
        if let documentView {
            documentView.setFrameSize(NSSize(width: contentSize.width, height: documentView.frame.height))
        }
    }

    // a short text leaves empty lines below it: a click there lands on the clip view
    override func mouseDown(with event: NSEvent) {
        guard let textView = documentView as? NSTextView else {
            super.mouseDown(with: event)
            return
        }
        window?.makeFirstResponder(textView)
        textView.mouseDown(with: event)
    }
}
