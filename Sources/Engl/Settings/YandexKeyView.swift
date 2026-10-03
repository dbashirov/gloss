import EnglCore
import SwiftUI

/// YandexKeyView edits, saves and checks the Yandex Dictionary API key.
struct YandexKeyView: View {
    static let keyURL = URL(string: "https://yandex.ru/dev/dictionary/keys/get/?service=dict")!

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
            if key.isLoading || key.isChecking {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            Link("Получить бесплатный ключ", destination: Self.keyURL)
        }
        SettingsNoteView(note: key.note)
    }
}
