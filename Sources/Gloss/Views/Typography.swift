import AppKit
import GlossCore
import SwiftUI

// the @Entry macro needs the SwiftUIMacros plugin missing from Command Line Tools
private struct TypographyKey: EnvironmentKey {
    static let defaultValue = PanelTypography(baseSize: PanelTypography.defaultSize)
}

extension EnvironmentValues {
    /// Text sizes and typeface of the panel, derived from the settings.
    var typography: PanelTypography {
        get { self[TypographyKey.self] }
        set { self[TypographyKey.self] = newValue }
    }
}

/// InstalledFonts lists the font families available on this Mac.
@MainActor
enum InstalledFonts {
    static let families = NSFontManager.shared.availableFontFamilies
        .filter { !$0.hasPrefix(".") }
    private static let familySet = Set(families)

    static func contains(_ family: String) -> Bool {
        familySet.contains(family)
    }
}

extension PanelTypography {
    /// Returns the chosen typeface at the size; a family removed from the Mac falls back
    /// to the system font.
    @MainActor
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch font {
        case .system:
            .system(size: size, weight: weight)
        case .rounded:
            .system(size: size, weight: weight, design: .rounded)
        case .serif:
            .system(size: size, weight: weight, design: .serif)
        case .monospaced:
            .system(size: size, weight: weight, design: .monospaced)
        case .family(let name):
            InstalledFonts.contains(name)
                ? .custom(name, size: size).weight(weight)
                : .system(size: size, weight: weight)
        }
    }

    /// Returns the same typeface as an AppKit font, for text views SwiftUI does not style.
    @MainActor
    func nsFont(size: CGFloat) -> NSFont {
        let system = NSFont.systemFont(ofSize: size)
        let design: NSFontDescriptor.SystemDesign
        switch font {
        case .system:
            return system
        case .rounded:
            design = .rounded
        case .serif:
            design = .serif
        case .monospaced:
            design = .monospaced
        case .family(let name):
            let manager = NSFontManager.shared
            return manager.font(withFamily: name, traits: [], weight: 5, size: size) ?? system
        }
        guard let descriptor = system.fontDescriptor.withDesign(design) else {
            return system
        }
        return NSFont(descriptor: descriptor, size: size) ?? system
    }
}
