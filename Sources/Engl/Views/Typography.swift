import EnglCore
import SwiftUI

// the @Entry macro needs the SwiftUIMacros plugin missing from Command Line Tools
private struct TypographyKey: EnvironmentKey {
    static let defaultValue = PanelTypography(baseSize: PanelTypography.defaultSize)
}

extension EnvironmentValues {
    /// Text sizes of the panel, derived from the font size in the settings.
    var typography: PanelTypography {
        get { self[TypographyKey.self] }
        set { self[TypographyKey.self] = newValue }
    }
}
