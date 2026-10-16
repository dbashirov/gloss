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
        let typography = PanelTypography(baseSize: settings.fontSize, font: settings.panelFont)
        VStack(alignment: .leading, spacing: 10) {
            HeaderView(
                isPinned: settings.isPinned,
                onTogglePin: actions.togglePin,
                onClose: actions.close
            )
            TextField("Слово или фраза", text: $model.query, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .focused($isQueryFocused)
                .onSubmit { translator.translate(model.query) }
                .help("Enter - перевести, ⌥Enter - новая строка")
            // notices scroll with the result: a small panel keeps the field and footer visible
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if model.isPasteAccessDenied {
                        NoticeView(
                            message: "Доступ к буферу обмена запрещён — двойной Cmd+C не работает",
                            action: .allowPasteboardAccess,
                            perform: actions.perform
                        )
                    }
                    stateContent
                    if case .result(let routed) = translator.state,
                       let notice = routed.fallbackNotice {
                        NoticeView(
                            message: notice.message,
                            action: notice.action,
                            perform: actions.perform
                        )
                        .font(typography.font(size: typography.caption))
                    }
                }
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
                Divider()
                FooterView(providerID: routed.providerID) {
                    actions.copy(routed.result.copyText)
                }
            }
        }
        .font(typography.font(size: typography.body))
        .environment(\.typography, typography)
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
