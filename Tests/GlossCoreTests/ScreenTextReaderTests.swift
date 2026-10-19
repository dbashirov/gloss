import CoreGraphics
import Testing
@testable import GlossCore

@MainActor
struct ScreenTextReaderTests {
    @Test func joinsRecognizedLines() async {
        let capture = FakeScreenCapture(image: blankImage)
        let recognizer = FakeTextRecognizer(lines: ["It was an extraordi-", "nary day"])
        let reader = ScreenTextReader(capture: capture, recognizer: recognizer)

        let outcome = await reader.read()

        #expect(outcome == .text("It was an extraordinary day"))
        #expect(capture.captures == 1)
        #expect(recognizer.recognitions == 1)
        #expect(!reader.isReading)
    }

    @Test func asksForAccessInsteadOfCapturing() async {
        let capture = FakeScreenCapture(hasAccess: false, image: blankImage)
        let recognizer = FakeTextRecognizer(lines: ["run"])
        let reader = ScreenTextReader(capture: capture, recognizer: recognizer)

        let outcome = await reader.read()

        #expect(outcome == .failed(.accessDenied))
        #expect(capture.accessRequests == 1)
        #expect(capture.captures == 0)
    }

    @Test func cancelledSelectionIsNotRecognized() async {
        let capture = FakeScreenCapture(image: nil)
        let recognizer = FakeTextRecognizer(lines: ["run"])
        let reader = ScreenTextReader(capture: capture, recognizer: recognizer)

        let outcome = await reader.read()

        #expect(outcome == .cancelled)
        #expect(recognizer.recognitions == 0)
    }

    @Test func reportsCaptureFailure() async {
        let capture = FakeScreenCapture { throw UnexpectedError() }
        let reader = ScreenTextReader(capture: capture, recognizer: FakeTextRecognizer(lines: []))

        #expect(await reader.read() == .failed(.captureFailed))
        #expect(!reader.isReading)
    }

    @Test func reportsRecognitionFailure() async {
        let capture = FakeScreenCapture(image: blankImage)
        let reader = ScreenTextReader(
            capture: capture,
            recognizer: FakeTextRecognizer(error: UnexpectedError())
        )

        #expect(await reader.read() == .failed(.recognitionFailed))
    }

    @Test(arguments: [[String](), ["  ", ""]])
    func reportsAreaWithoutText(lines: [String]) async {
        let capture = FakeScreenCapture(image: blankImage)
        let reader = ScreenTextReader(capture: capture, recognizer: FakeTextRecognizer(lines: lines))

        #expect(await reader.read() == .failed(.noText))
    }

    @Test(.timeLimit(.minutes(1)))
    func ignoresSecondReadWhileSelecting() async {
        let gate = Gate()
        let capture = FakeScreenCapture {
            await gate.wait()
            return blankImage
        }
        let reader = ScreenTextReader(capture: capture, recognizer: FakeTextRecognizer(lines: ["run"]))

        let first = Task { await reader.read() }
        while !reader.isReading {
            await Task.yield()
        }
        let second = await reader.read()
        gate.open()

        #expect(second == .cancelled)
        #expect(await first.value == .text("run"))
        #expect(capture.captures == 1)
    }
}
