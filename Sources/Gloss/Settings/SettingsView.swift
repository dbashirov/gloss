import GlossCore
import SwiftUI

/// SettingsView is the content of the settings window: the page of the selected tab.
struct SettingsView: View {
    let model: SettingsModel
    let settings: AppSettings
    let screenTextHotKey: GlobalHotKey
    let clipboardHotKey: GlobalHotKey

    var body: some View {
        Group {
            switch model.tab {
            case .general:
                GeneralSettingsView(model: model, settings: settings)
            case .appearance:
                AppearanceSettingsView(settings: settings)
            case .shortcuts:
                ShortcutsSettingsView(
                    model: model,
                    settings: settings,
                    screenTextHotKey: screenTextHotKey,
                    clipboardHotKey: clipboardHotKey
                )
            case .translation:
                TranslationSettingsView(model: model)
            }
        }
        .formStyle(.grouped)
        // the window follows the height of the page instead of scrolling it
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 500)
    }
}
