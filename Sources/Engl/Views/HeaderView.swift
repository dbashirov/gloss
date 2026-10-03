import SwiftUI

/// HeaderView is the panel's top bar: a drag handle, the pin toggle and the close button.
struct HeaderView: View {
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // isMovableByWindowBackground does not work over NSHostingView
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
            .help("Перетащить")

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
    }
}
