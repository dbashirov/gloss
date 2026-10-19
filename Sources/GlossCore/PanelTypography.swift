import CoreGraphics

/// PanelTypography derives the panel text sizes from the base size chosen in the settings,
/// keeping the proportions of the macOS text styles, and carries the chosen typeface.
public struct PanelTypography: Equatable, Sendable {
    public static let defaultSize: Double = 14
    public static let sizeRange: ClosedRange<Double> = 11...20
    private static let minCaption: CGFloat = 9

    /// The query field, translations and other regular text.
    public let body: CGFloat
    /// The looked up word in the dictionary card.
    public let title: CGFloat
    /// Meanings and examples.
    public let callout: CGFloat
    /// Parts of speech, notices and the translation source.
    public let caption: CGFloat
    public let font: PanelFont

    public init(baseSize: Double, font: PanelFont = .system) {
        self.font = font
        let base = CGFloat(Self.clamp(baseSize))
        body = base
        title = base + 4
        callout = base - 1
        caption = max(base - 3, Self.minCaption)
    }

    public static func clamp(_ size: Double) -> Double {
        min(max(size, sizeRange.lowerBound), sizeRange.upperBound)
    }
}
