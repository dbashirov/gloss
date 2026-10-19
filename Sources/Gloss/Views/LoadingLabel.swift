import SwiftUI

/// LoadingLabel is a small spinner with a secondary text, e.g. «Перевожу…».
struct LoadingLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
