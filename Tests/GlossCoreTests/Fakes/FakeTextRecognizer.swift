import CoreGraphics
import Synchronization
@testable import GlossCore

final class FakeTextRecognizer: TextRecognizing {
    private let result: Result<[RecognizedLine], UnexpectedError>
    private let calls = Mutex(0)

    /// Recognizes the lines as one paragraph.
    init(lines: [String]) {
        result = .success(layOut([lines]))
    }

    init(error: UnexpectedError) {
        result = .failure(error)
    }

    var recognitions: Int {
        calls.withLock { $0 }
    }

    func recognizeLines(in image: CGImage) async throws -> [RecognizedLine] {
        calls.withLock { $0 += 1 }
        return try result.get()
    }
}
