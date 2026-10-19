import CoreGraphics
import Synchronization
@testable import GlossCore

final class FakeTextRecognizer: TextRecognizing {
    private let result: Result<[String], UnexpectedError>
    private let calls = Mutex(0)

    init(lines: [String]) {
        result = .success(lines)
    }

    init(error: UnexpectedError) {
        result = .failure(error)
    }

    var recognitions: Int {
        calls.withLock { $0 }
    }

    func recognizeLines(in image: CGImage) async throws -> [String] {
        calls.withLock { $0 += 1 }
        return try result.get()
    }
}
