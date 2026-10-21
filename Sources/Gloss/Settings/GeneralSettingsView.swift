import GlossCore
import SwiftUI

/// GeneralSettingsView is the settings page with the login item and double Cmd+C.
struct GeneralSettingsView: View {
    static let intervalRange = DoubleCopyDetector.intervalRange.lowerBound.milliseconds
        ... DoubleCopyDetector.intervalRange.upperBound.milliseconds
    static let intervalStep = 50.0

    let model: SettingsModel
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                launchAtLogin
            }
            Section("Двойной Cmd+C") {
                doubleCopy
                pasteAccess
            }
        }
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

private extension Duration {
    var milliseconds: Double {
        self / .milliseconds(1)
    }
}
