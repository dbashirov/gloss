import GlossCore
import SwiftUI

/// TranslatorView is the panel content: the query field and the translation state.
struct TranslatorView: View {
    @Bindable var model: PanelModel
    let translator: TranslationController
    let settings: AppSettings
    let speech: Speech
    let actions: PanelActions

    private let resultHeight = State(initialValue: CGFloat(0))
    // everything but the result area: header, field, notices, footer and paddings
    private let chromeHeight = State(initialValue: CGFloat(150))
    private let fieldHeight = State(initialValue: CGFloat(0))
    /// The height of the field and the result area together, without the divider.
    private let fieldRoom = State(initialValue: CGFloat(0))
    /// The field height and the room of the result area when the divider drag began.
    private let dividerStart = State(initialValue: (field: CGFloat, resultRoom: CGFloat)?.none)

    var body: some View {
        // a size chosen by the user is filled by the content, the result area scrolls
        let isAutoSized = settings.panelSize == nil
        let resultLimit = PanelController.autoMaxHeight - chromeHeight.wrappedValue
        let scrollHeight = max(min(resultHeight.wrappedValue, resultLimit), 0)
        let typography = PanelTypography(baseSize: settings.fontSize, font: settings.panelFont)
        let fieldMinHeight = QueryField.minHeight(font: typography.nsFont(size: typography.body))
        let fieldFixedHeight = fixedFieldHeight(
            isAutoSized: isAutoSized,
            minHeight: fieldMinHeight
        )
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                isPinned: settings.isPinned,
                onTogglePin: actions.togglePin,
                onClose: actions.close
            )
            VStack(alignment: .leading, spacing: 10) {
                // the divider stands in for the spacing between the field and the result
                VStack(alignment: .leading, spacing: 0) {
                    QueryField(
                        text: $model.query,
                        fixedHeight: fieldFixedHeight,
                        focusRequest: model.focusRequest
                    ) {
                        model.screenTextError = nil
                        model.inputRevision += 1
                        translator.translate(model.query)
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        fieldHeight.wrappedValue = height
                    }
                    // the field keeps its set height, the result area gives way
                    .layoutPriority(1)
                    QueryDivider { offset in
                        let resultRoom = isAutoSized
                            ? resultLimit
                            : fieldRoom.wrappedValue - fieldHeight.wrappedValue
                        dragDivider(
                            by: offset,
                            resultRoom: resultRoom,
                            minHeight: fieldMinHeight
                        )
                    } onReset: {
                        if isAutoSized {
                            settings.queryFieldHeight = nil
                        } else {
                            settings.queryFieldShare = nil
                        }
                    }
                    // notices scroll with the result: a small panel keeps the field and footer
                    // visible
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if model.isPasteAccessDenied {
                                NoticeView(
                                    message: "Доступ к буферу обмена запрещён: двойной Cmd+C "
                                        + "не работает",
                                    action: .allowPasteboardAccess,
                                    perform: actions.perform
                                )
                            }
                            if let error = model.screenTextError {
                                NoticeView(
                                    message: error.message,
                                    action: error.action,
                                    perform: actions.perform
                                )
                            } else {
                                stateContent
                            }
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
                    .frame(
                        minHeight: isAutoSized ? nil : QueryFieldSizing.minResultHeight,
                        maxHeight: isAutoSized ? nil : .infinity
                    )
                    .scrollBounceBehavior(.basedOnSize)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    fieldRoom.wrappedValue = height - QueryDivider.height
                }
                if case .result(let routed) = translator.state {
                    Divider()
                    FooterView(providerID: routed.providerID) {
                        actions.copy(routed.result.copyText)
                    }
                }
            }
            .padding(.horizontal, HeaderView.inset)
        }
        .font(typography.font(size: typography.body))
        .environment(\.typography, typography)
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
    }

    private func dragDivider(by offset: CGFloat?, resultRoom: CGFloat, minHeight: CGFloat) {
        guard let offset else {
            dividerStart.wrappedValue = nil
            return
        }
        let start = dividerStart.wrappedValue ?? (fieldHeight.wrappedValue, resultRoom)
        dividerStart.wrappedValue = start
        let height = QueryFieldSizing.height(
            dragging: start.field,
            by: offset,
            minHeight: minHeight,
            resultRoom: start.resultRoom
        )
        if settings.panelSize == nil {
            settings.queryFieldHeight = Double(height)
        } else {
            let room = fieldRoom.wrappedValue
            settings.queryFieldShare = QueryFieldSizing.share(of: height, room: room)
        }
    }

    // a panel sized by the user splits its height by a share, so the divider moves with
    // the panel's edge; one that follows its content has no height to split
    private func fixedFieldHeight(isAutoSized: Bool, minHeight: CGFloat) -> CGFloat? {
        if isAutoSized {
            return settings.queryFieldHeight.map { CGFloat($0) }
        }
        let room = fieldRoom.wrappedValue
        guard room > 0 else {
            return nil
        }
        let share = settings.queryFieldShare ?? QueryFieldSizing.defaultShare
        return QueryFieldSizing.height(share: share, room: room, minHeight: minHeight)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch translator.state {
        case .idle:
            Text("Введите слово или фразу и нажмите Enter, ⇧Enter - новая строка")
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
