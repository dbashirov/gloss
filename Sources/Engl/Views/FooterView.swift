import EnglCore
import SwiftUI

/// FooterView names the translation source and copies the translation.
struct FooterView: View {
    let providerID: String
    let onCopy: () -> Void

    @Environment(\.typography) private var typography
    private let copyCount = State(initialValue: 0)

    var body: some View {
        let info = ProviderInfo.info(for: providerID)
        HStack(spacing: 8) {
            Group {
                if let url = info.url {
                    Link(info.name, destination: url)
                } else {
                    Text(info.name)
                }
            }
            .font(typography.font(size: typography.caption))
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                onCopy()
                copyCount.wrappedValue += 1
            } label: {
                Image(systemName: "doc.on.doc")
                    .symbolEffect(.bounce, value: copyCount.wrappedValue)
            }
            .buttonStyle(.borderless)
            .help("Копировать перевод")
        }
    }
}
