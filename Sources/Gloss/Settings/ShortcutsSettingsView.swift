import GlossCore
import SwiftUI

/// ShortcutsSettingsView is the settings page with the global hot keys: screen text
/// and copied text.
struct ShortcutsSettingsView: View {
    let model: SettingsModel
    @Bindable var settings: AppSettings
    let screenTextHotKey: GlobalHotKey
    let clipboardHotKey: GlobalHotKey

    var body: some View {
        Form {
            Section("Текст с экрана") {
                screenText
            }
            Section("Скопированный текст") {
                clipboardText
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
