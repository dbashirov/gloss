import EnglCore
import SwiftUI

/// TranslatorView is the panel content: the query field and the translation state.
struct TranslatorView: View {
    static let pasteAccessMessage = "Доступ к буферу обмена запрещён — двойной Cmd+C не работает"

    @Bindable var model: PanelModel
    let translator: TranslationController
    let settings: AppSettings
    let speech: Speech
    let actions: PanelActions

    @FocusState private var isQueryFocused: Bool
    // the @State macro needs SwiftUIMacros, which Command Line Tools lack
    private let resultHeight = State(initialValue: CGFloat(0))
    // everything but the result area: header, field, notices, footer and paddings
    private let chromeHeight = State(initialValue: CGFloat(150))

    var body: some View {
        let resultLimit = PanelController.maxHeight - chromeHeight.wrappedValue
        let scrollHeight = max(min(resultHeight.wrappedValue, resultLimit), 0)
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
                    message: Self.pasteAccessMessage,
                    action: .allowPasteboardAccess,
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
            .frame(height: scrollHeight)
            .scrollBounceBehavior(.basedOnSize)
            if case .result(let routed) = translator.state {
                if let notice = routed.fallbackNotice {
                    NoticeView(
                        message: notice.message,
                        action: notice.action,
                        perform: actions.perform
                    )
                    .font(.caption)
                }
                Divider()
                FooterView(providerID: routed.providerID) {
                    actions.copy(routed.result.copyText)
                }
            }
        }
        .padding(12)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            let chrome = height - scrollHeight
            if abs(chrome - chromeHeight.wrappedValue) > 0.5 {
                chromeHeight.wrappedValue = chrome
            }
        }
        .frame(width: PanelController.width, alignment: .leading)
        // keeps the header with its buttons visible while the height settles
        .frame(maxHeight: PanelController.maxHeight, alignment: .top)
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
        case .failed(let error):
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
