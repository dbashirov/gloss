import EnglCore
import SwiftUI

/// SettingsView is the content of the settings window.
struct SettingsView: View {
    static let intervalRange = DoubleCopyDetector.intervalRange.lowerBound.milliseconds
        ... DoubleCopyDetector.intervalRange.upperBound.milliseconds
    static let intervalStep = 50.0

    @Bindable var model: SettingsModel
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Основные") {
                launchAtLogin
                doubleCopy
                pasteAccess
            }
            Section("Внешний вид") {
                fontSize
            }
            Section("Словари") {
                YandexKeyView(key: model.key)
            }
            Section("Языковой пакет") {
                LanguagePackView(model: model)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 680)
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
            Caption("Доступно, когда Engl установлен в папку «Программы» (/Applications)")
        case .requiresApproval:
            HStack {
                Caption("Разрешите запуск Engl в «Объектах входа»")
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

    private var intervalMilliseconds: Binding<Double> {
        Binding(
            get: { settings.doubleCopyInterval.milliseconds },
            set: { settings.doubleCopyInterval = .milliseconds($0) }
        )
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
