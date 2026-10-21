import SwiftUI

/// TranslationSettingsView is the settings page with the translation sources:
/// the Yandex dictionary key and the Apple Translation language pack.
struct TranslationSettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Словари") {
                YandexKeyView(key: model.key)
            }
            Section("Языковой пакет") {
                LanguagePackView(model: model)
            }
        }
    }
}
