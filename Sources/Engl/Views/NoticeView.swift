import EnglCore
import SwiftUI

/// NoticeView shows a problem and the action that fixes it.
struct NoticeView: View {
    let message: String
    let action: ErrorAction?
    let perform: (ErrorAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action.title) {
                    perform(action)
                }
                .controlSize(.small)
            }
        }
    }
}
