import CoreGraphics

/// ScreenTextReader takes text from the screen: the user selects an area, its text is
/// recognized and joined into a query.
@MainActor
public final class ScreenTextReader {
    public enum Outcome: Sendable, Equatable {
        case text(String)
        case failed(ScreenTextError)
        /// The user cancelled the selection or a selection is already in progress.
        case cancelled
    }

    private let capture: any ScreenCapturing
    private let recognizer: any TextRecognizing
    private(set) var isReading = false

    public init(capture: any ScreenCapturing, recognizer: any TextRecognizing) {
        self.capture = capture
        self.recognizer = recognizer
    }

    public func read() async -> Outcome {
        // a second hot key press while the user is selecting would start another selection
        guard !isReading else {
            return .cancelled
        }
        guard capture.hasAccess else {
            capture.requestAccess()
            return .failed(.accessDenied)
        }
        isReading = true
        defer { isReading = false }
        let image: CGImage?
        do {
            image = try await capture.captureSelection()
        } catch {
            return .failed(.captureFailed)
        }
        guard let image else {
            return .cancelled
        }
        do {
            let lines = try await recognizer.recognizeLines(in: image)
            return RecognizedText.join(lines).map(Outcome.text) ?? .failed(.noText)
        } catch {
            return .failed(.recognitionFailed)
        }
    }
}
