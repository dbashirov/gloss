import Testing
@testable import GlossCore

struct PanelFontTests {
    @Test(arguments: [
        PanelFont.system,
        .rounded,
        .serif,
        .monospaced,
        .family("Georgia"),
        .family("PT Serif: Caption"),
    ])
    func restoresStoredValue(font: PanelFont) {
        #expect(PanelFont(storageValue: font.storageValue) == font)
    }

    @Test(arguments: ["", "family:", "fancy", "Georgia"])
    func rejectsUnknownValue(value: String) {
        #expect(PanelFont(storageValue: value) == nil)
    }
}
