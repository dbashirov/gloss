import EnglCore
import SwiftUI

/// TranslatorView is the panel content: the query field and the translation state.
struct TranslatorView: View {
    @Bindable var model: PanelModel
    let translator: TranslationController
    let settings: AppSettings
    let speech: Speech
    let actions: PanelActions

    @FocusState private var isQueryFocused: Bool
    private let resultHeight = State(initialValue: CGFloat(0))
    // everything but the result area: header, field, notices, footer and paddings
    private let chromeHeight = State(initialValue: CGFloat(150))

    var body: some View {
        // a size chosen by the user is filled by the content, the result area scrolls
        let isAutoSized = settings.panelSize == nil
        let resultLimit = PanelController.autoMaxHeight - chromeHeight.wrappedValue
        let scrollHeight = max(min(resultHeight.wrappedValue, resultLimit), 0)
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(
                isPinned: settings.isPinned,
                onTogglePin: actions.togglePin,
                onClose: actions.close
            )
            TextField("Слово или фраза", text: $model.query, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.roundedBorder)
                .focused($isQueryFocused)
                .onSubmit { translator.translate(model.query) }
                .help("Enter — перевести, ⌥Enter — новая строка")
            if model.isPasteAccessDenied {
                NoticeView(
                    message: "Доступ к буферу обмена запрещён — двойной Cmd+C не работает",
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
            .frame(height: isAutoSized ? scrollHeight : nil)
            .frame(maxHeight: isAutoSized ? nil : .infinity)
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
        .padding([.horizontal, .top], 12)
        // room for the resize grip below the footer
        .padding(.bottom, 16)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            let chrome = height - scrollHeight
            if isAutoSized, abs(chrome - chromeHeight.wrappedValue) > 0.5 {
                chromeHeight.wrappedValue = chrome
            }
        }
        .frame(width: isAutoSized ? PanelController.autoWidth : nil, alignment: .leading)
        // keeps the header with its buttons visible while the height settles
        .frame(
            maxWidth: isAutoSized ? nil : .infinity,
            maxHeight: isAutoSized ? PanelController.autoMaxHeight : .infinity,
            alignment: .top
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomTrailing) {
            ResizeGrip(onResize: actions.resize, onReset: actions.resetSize)
                .padding(2)
        }
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
            LoadingLabel("Перевожу…")
        case .result(let routed):
            switch routed.result {
            case .dictionary(let entry):
                DictionaryCardView(entry: entry) {
                    speech.speak(entry.word, language: entry.language)
                }
            case .text(let translation):
                TextResultView(translation: translation)
            }
        case .failed(let error):
            NoticeView(message: error.message, action: error.action, perform: actions.perform)
        }
    }
}
