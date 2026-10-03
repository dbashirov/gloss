import Synchronization
import Translation
@testable import EnglCore

final class FakeTextTranslator: TextTranslator {
    typealias Handler = @Sendable (String) async throws -> String

    private let availability: LanguageAvailability.Status
    private let handler: Handler
    private let received = Mutex<[String]>([])

    init(status: LanguageAvailability.Status = .installed, handler: @escaping Handler) {
        self.availability = status
        self.handler = handler
    }

    convenience init(status: LanguageAvailability.Status = .installed, translation: String) {
        self.init(status: status) { _ in translation }
    }

    convenience init(error: any Error & Sendable) {
        self.init { _ in throw error }
    }

    var texts: [String] {
        received.withLock { $0 }
    }

    func status(
        from source: Language,
        to target: Language
    ) async -> LanguageAvailability.Status {
        availability
    }

    func translate(
        _ text: String,
        from source: Language,
        to target: Language
    ) async throws -> String {
        received.withLock { $0.append(text) }
        return try await handler(text)
    }
}
