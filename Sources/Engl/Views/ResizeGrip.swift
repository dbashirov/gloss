import SwiftUI

/// ResizeGrip is the panel's bottom-right corner: a drag resizes the panel, a double
/// click returns it to the size of its content.
struct ResizeGrip: View {
    let onResize: (PanelResizePhase) -> Void
    let onReset: () -> Void

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 12, height: 12)
            .contentShape(Rectangle())
            // the panel moves while it resizes: the controller tracks the screen cursor
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in onResize(.changed) }
                    .onEnded { _ in onResize(.ended) }
            )
            .onTapGesture(count: 2, perform: onReset)
            .allowsWindowActivationEvents(true)
            .pointerStyle(.frameResize(position: .bottomTrailing))
            .help("Потяните, чтобы изменить размер. Двойной клик — размер по содержимому")
    }
}
