import GlossCore
import SwiftUI

/// AppearanceSettingsView is the settings page with the font of the translator panel.
struct AppearanceSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Окно перевода") {
                fontPicker
                fontSize
                fontPreview
            }
        }
    }

    private var fontPicker: some View {
        Picker("Шрифт", selection: $settings.panelFont) {
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

    private var fontSize: some View {
        LabeledContent("Размер шрифта") {
            HStack {
                Slider(value: $settings.fontSize, in: PanelTypography.sizeRange, step: 1)
                Text("\(Int(settings.fontSize)) pt")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
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
}
