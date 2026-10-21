import AppKit
import SwiftUI

/// QueryDivider sits between the query field and the result: a vertical drag moves the
/// border between them, a double click fits the field to its text again.
struct QueryDivider: View {
    /// Called with how far the cursor moved down since the drag began; `nil` ends it.
    let onDrag: (CGFloat?) -> Void
    let onReset: () -> Void

    private let dragStartY = State(initialValue: CGFloat?.none)
    private let isHovered = State(initialValue: false)

    var body: some View {
        let isActive = isHovered.wrappedValue || dragStartY.wrappedValue != nil
        Capsule()
            .fill(Color.secondary.opacity(isActive ? 0.6 : 0.3))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 12)
            .contentShape(Rectangle())
            // the panel may move while it follows its content: the screen cursor is tracked
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        let cursorY = NSEvent.mouseLocation.y
                        let startY = dragStartY.wrappedValue ?? cursorY
                        dragStartY.wrappedValue = startY
                        // screen y grows upwards
                        onDrag(startY - cursorY)
                    }
                    .onEnded { _ in
                        dragStartY.wrappedValue = nil
                        onDrag(nil)
                    }
            )
            .onTapGesture(count: 2, perform: onReset)
            .onHover { isHovered.wrappedValue = $0 }
            .allowsWindowActivationEvents(true)
            .pointerStyle(.frameResize(position: .bottom))
            .help("Потяните, чтобы изменить высоту поля. Двойной клик - по тексту")
    }
}
