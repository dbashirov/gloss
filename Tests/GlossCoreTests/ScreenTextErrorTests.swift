import Testing
@testable import GlossCore

struct ScreenTextErrorTests {
    @Test(arguments: ScreenTextError.allCases)
    func everyErrorHasRussianMessage(error: ScreenTextError) {
        #expect(error.message.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) })
    }

    @Test func messagesAreDistinct() {
        let messages = Set(ScreenTextError.allCases.map(\.message))
        #expect(messages.count == ScreenTextError.allCases.count)
    }

    @Test(arguments: [
        (ScreenTextError.accessDenied, ErrorAction?.some(.allowScreenRecording)),
        (.captureFailed, nil),
        (.noText, nil),
        (.recognitionFailed, nil),
    ])
    func mapsErrorToAction(error: ScreenTextError, action: ErrorAction?) {
        #expect(error.action == action)
    }
}
