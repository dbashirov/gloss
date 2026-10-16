import CoreGraphics

/// ScreenCapturing lets the user select a screen area and returns its image.
@MainActor
public protocol ScreenCapturing {
    /// Tells whether Privacy & Security allows Engl to record the screen.
    var hasAccess: Bool { get }

    /// Asks for the screen recording access; the system shows its prompt only once.
    func requestAccess()

    /// Returns the image of the selected area, `nil` when the user cancelled the selection.
    func captureSelection() async throws -> CGImage?
}

/// TextRecognizing finds the lines of text in an image.
public protocol TextRecognizing: Sendable {
    /// Returns the lines in reading order.
    func recognizeLines(in image: CGImage) async throws -> [String]
}
