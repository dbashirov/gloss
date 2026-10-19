import CoreGraphics
@testable import GlossCore

@MainActor
final class FakeScreenCapture: ScreenCapturing {
    typealias Handler = @MainActor () async throws -> CGImage?

    var hasAccess: Bool
    private(set) var accessRequests = 0
    private(set) var captures = 0
    private let handler: Handler

    init(hasAccess: Bool = true, handler: @escaping Handler) {
        self.hasAccess = hasAccess
        self.handler = handler
    }

    convenience init(hasAccess: Bool = true, image: CGImage?) {
        self.init(hasAccess: hasAccess) { image }
    }

    func requestAccess() {
        accessRequests += 1
    }

    func captureSelection() async throws -> CGImage? {
        captures += 1
        return try await handler()
    }
}
