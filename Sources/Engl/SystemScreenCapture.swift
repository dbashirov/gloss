import CoreGraphics
import EnglCore
import Foundation
import ImageIO

/// SystemScreenCapture selects a screen area with the system `screencapture` tool:
/// the same crosshair as ⌘⇧4, Esc cancels.
@MainActor
final class SystemScreenCapture: ScreenCapturing {
    private static let toolURL = URL(filePath: "/usr/sbin/screencapture")

    var hasAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestAccess() {
        CGRequestScreenCaptureAccess()
    }

    func captureSelection() async throws -> CGImage? {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "engl-capture-\(ProcessInfo.processInfo.globallyUniqueString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        let process = Process()
        process.executableURL = Self.toolURL
        // -i interactive, -s selection only, -x no sound
        process.arguments = ["-i", "-s", "-x", url.path(percentEncoded: false)]
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            // Esc leaves no file, a crashed tool neither
            if process.terminationReason == .uncaughtSignal {
                throw ScreenTextError.captureFailed
            }
            return nil
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ScreenTextError.captureFailed
        }
        return image
    }
}
