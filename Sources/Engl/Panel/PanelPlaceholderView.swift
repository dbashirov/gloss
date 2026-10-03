import EnglCore
import Observation
import SwiftUI

/// PanelModel holds the panel input shared between the controller and the SwiftUI view.
@MainActor
@Observable
final class PanelModel {
    var query = ""
    /// Incremented on every show to move the focus into the query field.
    var focusRequest = 0
}

/// PanelPlaceholderView is a minimal panel content until the real views (Task 12).
struct PanelPlaceholderView: View {
    @Bindable var model: PanelModel
    let translator: TranslationController
    let settings: AppSettings
    let onTogglePin: () -> Void

    @FocusState private var isQueryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .gesture(WindowDragGesture())
                TextField("Слово или фраза", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .focused($isQueryFocused)
                    .onSubmit { translator.translate(model.query) }
                Button(action: onTogglePin) {
                    Image(systemName: settings.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
                .help(settings.isPinned ? "Открепить" : "Закрепить")
            }
            Text(Self.describe(translator.state))
                .lineLimit(16)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(width: PanelController.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: model.focusRequest) {
            isQueryFocused = true
        }
    }

    private static func describe(_ state: TranslationController.State) -> String {
        switch state {
        case .idle:
            "Введите слово или фразу"
        case .loading:
            "Перевожу…"
        case .result(let routed):
            "\(describe(routed.result))\n— \(routed.providerID)"
        case .failed(_, let error):
            "Ошибка: \(error)"
        }
    }

    private static func describe(_ result: TranslationResult) -> String {
        switch result {
        case .dictionary(let entry):
            let senses = entry.groups.flatMap(\.translations).map(\.text)
            return "\(entry.word): \(senses.joined(separator: ", "))"
        case .text(let translation):
            return translation.translation
        }
    }
}
