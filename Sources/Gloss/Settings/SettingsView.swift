import GlossCore
import SwiftUI

/// SettingsView is the content of the settings window.
struct SettingsView: View {
    static let intervalRange = DoubleCopyDetector.intervalRange.lowerBound.milliseconds
        ... DoubleCopyDetector.intervalRange.upperBound.milliseconds
    static let intervalStep = 50.0

    @Bindable var model: SettingsModel
    @Bindable var settings: AppSettings
    let screenTextHotKey: GlobalHotKey
    let clipboardHotKey: GlobalHotKey

    var body: some View {
        Form {
            Section("Основные") {
                launchAtLogin
                doubleCopy
                pasteAccess
            }
            Section("Текст с экрана") {
                screenText
            }
            Section("Скопированный текст") {
                clipboardText
            }
            Section("Внешний вид") {
                fontPicker
                fontSize
                fontPreview
            }
            Section("Словари") {
                YandexKeyView(key: model.key)
            }
            Section("Языковой пакет") {
                LanguagePackView(model: model)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: model.formHeight)
    }

    @ViewBuilder
    private var launchAtLogin: some View {
        Toggle("Запускать при входе в систему", isOn: Binding(
            get: { model.launchState.isOn },
            set: { model.setLaunchAtLogin($0) }
        ))
        .disabled(model.launchState == .unavailable)
        switch model.launchState {
        case .unavailable:
            Caption("Доступно, когда Gloss установлен в папку «Программы» (/Applications)")
        case .requiresApproval:
            HStack {
                Caption("Разрешите запуск Gloss в «Объектах входа»")
                Spacer()
                Button("Открыть") {
                    SystemSettingsLink.loginItems.open()
                }
            }
        case .disabled, .enabled:
            EmptyView()
        }
        SettingsNoteView(note: model.launchNote)
    }

    @ViewBuilder
    private var doubleCopy: some View {
        Toggle("Перевод по двойному Cmd+C", isOn: $settings.doubleCopyEnabled)
        LabeledContent("Интервал между нажатиями") {
            HStack {
                Slider(
                    value: intervalMilliseconds,
                    in: Self.intervalRange,
                    step: Self.intervalStep
                )
                Text("\(Int(intervalMilliseconds.wrappedValue)) мс")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .disabled(!settings.doubleCopyEnabled)
    }

    private var fontPicker: some View {
        Picker("Шрифт в окне перевода", selection: $settings.panelFont) {
            Text("Системный").tag(PanelFont.system)
            Text("Системный скруглённый").tag(PanelFont.rounded)
            Text("С засечками (New York)").tag(PanelFont.serif)
            Text("Моноширинный").tag(PanelFont.monospaced)
            Divider()
            // a family chosen earlier and removed from the Mac stays selectable
            if case .family(let name) = settings.panelFont, !InstalledFonts.contains(name) {
                Text("\(name) (не установлен)").tag(settings.panelFont)
            }
            ForEach(InstalledFonts.families, id: \.self) { family in
                Text(family).tag(PanelFont.family(family))
            }
        }
    }

    private var fontPreview: some View {
        let typography = PanelTypography(baseSize: settings.fontSize, font: settings.panelFont)
        return Text("The quick brown fox jumps over the lazy dog - Съешь же ещё этих булок")
            .font(typography.font(size: typography.body))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var fontSize: some View {
        LabeledContent("Размер шрифта в окне перевода") {
            HStack {
                Slider(value: $settings.fontSize, in: PanelTypography.sizeRange, step: 1)
                Text("\(Int(settings.fontSize)) pt")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var pasteAccess: some View {
        LabeledContent("Доступ к буферу обмена", value: model.pasteAccess.status)
        if let hint = model.pasteAccess.hint {
            HStack {
                Caption(hint)
                Spacer()
                Button("Открыть") {
                    SystemSettingsLink.pasteAccess.open()
                }
            }
        }
    }

    @ViewBuilder
    private var screenText: some View {
        HotKeyRow(
            title: "Выделить область и перевести по горячей клавише",
            isOn: $settings.screenTextHotKeyEnabled,
            hotKey: $settings.screenTextHotKey,
            defaultHotKey: .screenTextDefault,
            otherHotKey: settings.clipboardHotKey,
            isTaken: screenTextHotKey.isTaken,
            onRecordingChange: suspendHotKeys
        )
        Caption("Без горячей клавиши - пункт «Перевести текст с экрана» в меню иконки")
        LabeledContent(
            "Доступ к записи экрана",
            value: model.hasScreenRecordingAccess ? "Разрешён" : "Не разрешён"
        )
        if !model.hasScreenRecordingAccess {
            HStack {
                Caption("Включите Gloss в «Запись экрана и системного звука» и перезапустите Gloss")
                Spacer()
                Button("Открыть") {
                    model.allowScreenRecording()
                }
            }
        }
    }

    @ViewBuilder
    private var clipboardText: some View {
        HotKeyRow(
            title: "Перевести скопированный текст по горячей клавише",
            isOn: $settings.clipboardHotKeyEnabled,
            hotKey: $settings.clipboardHotKey,
            defaultHotKey: .clipboardDefault,
            otherHotKey: settings.screenTextHotKey,
            isTaken: clipboardHotKey.isTaken,
            onRecordingChange: suspendHotKeys
        )
        Caption(
            "Когда двойной Cmd+C не срабатывает: например, терминал сам копирует выделение "
                + "мышью, и второе нажатие не меняет буфер"
        )
    }

    // a press of the other hot key must reach the recorder too
    private func suspendHotKeys(_ isSuspended: Bool) {
        screenTextHotKey.isSuspended = isSuspended
        clipboardHotKey.isSuspended = isSuspended
    }

    private var intervalMilliseconds: Binding<Double> {
        Binding(
            get: { settings.doubleCopyInterval.milliseconds },
            set: { settings.doubleCopyInterval = .milliseconds($0) }
        )
    }
}

/// HotKeyRow turns a global hot key on and off and records its combination.
private struct HotKeyRow: View {
    let title: String
    @Binding var isOn: Bool
    @Binding var hotKey: HotKey
    let defaultHotKey: HotKey
    /// The combination of the other Gloss hot key, which this one cannot take.
    let otherHotKey: HotKey
    let isTaken: Bool
    let onRecordingChange: (Bool) -> Void

    var body: some View {
        Toggle(title, isOn: $isOn)
        LabeledContent("Горячая клавиша") {
            HStack(alignment: .firstTextBaseline) {
                if hotKey != defaultHotKey && otherHotKey != defaultHotKey {
                    Button("Сбросить") {
                        hotKey = defaultHotKey
                    }
                }
                HotKeyRecorder(
                    hotKey: hotKey,
                    reserved: otherHotKey,
                    onRecord: { hotKey = $0 },
                    onRecordingChange: onRecordingChange
                )
            }
        }
        if isOn && isTaken {
            Caption("Сочетание занято другим приложением: выберите другое")
        }
    }
}

/// Caption is secondary explanatory text under a control.
private struct Caption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension Duration {
    var milliseconds: Double {
        self / .milliseconds(1)
    }
}
