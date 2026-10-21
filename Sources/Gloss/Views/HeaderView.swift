import SwiftUI

/// HeaderView is the panel's top bar with the pin toggle and the close button; the whole
/// bar drags the panel. It takes the panel's top and side insets, so the strip above the
/// field drags up to the edges.
struct HeaderView: View {
    static let inset: CGFloat = 12
    static let bottomInset: CGFloat = 10

    let isPinned: Bool
    let onTogglePin: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()

            Button(action: onTogglePin) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
            }
            .help(isPinned ? "Открепить" : "Закрепить")

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .help("Закрыть")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding([.horizontal, .top], Self.inset)
        .padding(.bottom, Self.bottomInset)
        // isMovableByWindowBackground does not work over NSHostingView; the buttons
        // take their clicks before the drag
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
    }
}
