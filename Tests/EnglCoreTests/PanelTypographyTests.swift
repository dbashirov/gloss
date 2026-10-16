import CoreGraphics
import Testing
@testable import EnglCore

struct PanelTypographyTests {
    @Test func keepsTextStyleProportions() {
        let typography = PanelTypography(baseSize: 13)

        #expect(typography.body == 13)
        #expect(typography.title == 17)
        #expect(typography.callout == 12)
        #expect(typography.caption == 10)
    }

    @Test func carriesChosenFont() {
        #expect(PanelTypography(baseSize: 13).font == .system)
        #expect(PanelTypography(baseSize: 13, font: .serif).font == .serif)
    }

    @Test func captionNeverGetsTooSmall() {
        #expect(PanelTypography(baseSize: 11).caption == 9)
    }

    @Test(arguments: [
        (5.0, 11.0),
        (11.0, 11.0),
        (16.5, 16.5),
        (20.0, 20.0),
        (48.0, 20.0),
    ])
    func clampsBaseSizeToRange(size: Double, expected: Double) {
        #expect(PanelTypography.clamp(size) == expected)
        #expect(PanelTypography(baseSize: size).body == CGFloat(expected))
    }
}
