import AppKit
import EnglCore
import SwiftUI

/// SettingsView is the content of the settings window.
struct SettingsView: View {
    static let intervalRange = DoubleCopyDetector.intervalRange.lowerBound.milliseconds
        ... DoubleCopyDetector.intervalRange.upperBound.milliseconds

    @Bindable var model: SettingsModel
    @Bindable var settings: AppSettings
    let onDoubleCopyChange: () -> Void

    var body: some View {
        Form {
            Section("Основные") {
                launchAtLogin
                doubleCopy
                pasteAccess
            }
            Section("Словари") {
                YandexKeyView(key: model.key)
            }
            Section("Языковой пакет") {
                LanguagePackView(model: model)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 620)
        .onChange(of: settings.doubleCopyEnabled) {
            onDoubleCopyChange()
        }
        .onChange(of: settings.doubleCopyInterval) {
            onDoubleCopyChange()
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
            Caption("Доступно, когда Engl установлен в папку «Программы» (/Applications)")
        case .requiresApproval:
            HStack {
                Caption("Разрешите запуск Engl в «Объектах входа»")
                Spacer()
                Button("Открыть") {
                    model.openLoginItems()
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
                Slider(value: intervalMilliseconds, in: Self.intervalRange, step: 50)
                Text("\(Int(intervalMilliseconds.wrappedValue)) мс")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .disabled(!settings.doubleCopyEnabled)
    }

    @ViewBuilder
    private var pasteAccess: some View {
        let access = PasteAccessDescription(model.pasteAccess)
        LabeledContent("Доступ к буферу обмена", value: access.status)
        if let hint = access.hint {
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
            get: { settings.doubleCopyInterval * 1000 },
            set: { settings.doubleCopyInterval = $0 / 1000 }
        )
    }
}

/// YandexKeyView edits, saves and checks the Yandex Dictionary API key.
struct YandexKeyView: View {
    @Bindable var key: YandexKeySettings

    var body: some View {
        SecureField("Ключ API Яндекс.Словаря", text: $key.draft)
            .onSubmit { key.save() }
        HStack {
            Button("Сохранить") {
                key.save()
            }
            .disabled(!key.canSave)
            Button("Проверить") {
                key.check()
            }
            .disabled(key.isChecking)
            if key.isChecking {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            Link("Получить бесплатный ключ", destination: SettingsModel.keyURL)
        }
        SettingsNoteView(note: key.note)
    }
}

/// PasteAccessDescription explains `NSPasteboard.AccessBehavior` for double Cmd+C.
struct PasteAccessDescription {
    let status: String
    let hint: String?

    init(_ behavior: NSPasteboard.AccessBehavior) {
        switch behavior {
        case .alwaysAllow:
            status = "Разрешён"
            hint = nil
        case .alwaysDeny:
            status = "Запрещён"
            hint = "Двойной Cmd+C не сможет прочитать текст: разрешите Engl в "
                + "«Конфиденциальность и безопасность → Вставка из других приложений»"
        default:
            status = "Спрашивать"
            hint = "При первом двойном Cmd+C система спросит разрешение — выберите "
                + "«Разрешать всегда»"
        }
    }
}

/// Caption is secondary explanatory text under a control.
struct Caption: View {
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

/// SettingsNoteView shows the outcome of the last action, if any.
struct SettingsNoteView: View {
    let note: SettingsNote?

    var body: some View {
        if let note {
            Label(note.text, systemImage: note.isError ? "exclamationmark.triangle" : "checkmark")
                .font(.caption)
                .foregroundStyle(note.isError ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Duration {
    var milliseconds: Double {
        self / .milliseconds(1)
    }
}
