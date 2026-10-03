import EnglCore
import SwiftUI

/// TranslatorView is the panel content: the query field and the translation state.
struct TranslatorView: View {
    // header, query field, footer and paddings take the rest of the panel height
    static let maxResultHeight = PanelController.maxHeight - 150

    @Bindable var model: PanelModel
    let translator: TranslationController
    let settings: AppSettings
    let speech: Speech
    let actions: PanelActions

    @FocusState private var isQueryFocused: Bool
    // the @State macro needs SwiftUIMacros, which Command Line Tools lack
    private let resultHeight = State(initialValue: CGFloat(0))

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(
                isPinned: settings.isPinned,
                onTogglePin: actions.togglePin,
                onClose: actions.close
            )
            TextField("Слово или фраза", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .focused($isQueryFocused)
                .onSubmit { translator.translate(model.query) }
            if model.isPasteAccessDenied {
                NoticeView(
                    message: PasteboardAccessHint.message,
                    action: PasteboardAccessHint.action,
                    perform: actions.perform
                )
            }
            ScrollView {
                stateContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        resultHeight.wrappedValue = height
                    }
            }
            .frame(height: min(resultHeight.wrappedValue, Self.maxResultHeight))
            .scrollBounceBehavior(.basedOnSize)
            if case .result(let routed) = translator.state {
                Divider()
                FooterView(providerID: routed.providerID) {
                    actions.copy(routed.result.copyText)
                }
            }
        }
        .padding(12)
        .frame(width: PanelController.width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: model.focusRequest) {
            isQueryFocused = true
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch translator.state {
        case .idle:
            Text("Введите слово или фразу и нажмите Enter")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Перевожу…")
                    .foregroundStyle(.secondary)
            }
        case .result(let routed):
            switch routed.result {
            case .dictionary(let entry):
                DictionaryCardView(entry: entry) {
                    let language = QueryClassifier.classify(entry.word).source
                    speech.speak(entry.word, language: language)
                }
            case .text(let translation):
                TextResultView(translation: translation)
            }
        case .failed(_, let error):
            NoticeView(message: error.message, action: error.action, perform: actions.perform)
        }
    }
}

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
