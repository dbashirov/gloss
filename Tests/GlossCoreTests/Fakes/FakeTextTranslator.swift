import Synchronization
import Translation
@testable import GlossCore

final class FakeTextTranslator: TextTranslator {
    typealias Handler = @Sendable (String) async throws -> String

    struct Direction: Hashable {
        static let enRu = Direction(source: .en, target: .ru)
        static let ruEn = Direction(source: .ru, target: .en)

        let source: Language
        let target: Language
    }

    private struct Calls {
        var texts: [String] = []
        var statusDirections: [Direction] = []
        var translateDirections: [Direction] = []
    }

    private let statuses: [Direction: LanguageAvailability.Status]
    private let handler: Handler
    private let calls = Mutex(Calls())

    /// A direction missing from `statuses` is `.unsupported`.
    init(statuses: [Direction: LanguageAvailability.Status], handler: @escaping Handler) {
        self.statuses = statuses
        self.handler = handler
    }

    convenience init(
        status: LanguageAvailability.Status = .installed,
        handler: @escaping Handler
    ) {
        self.init(statuses: [.enRu: status, .ruEn: status], handler: handler)
    }

    convenience init(status: LanguageAvailability.Status = .installed, translation: String) {
        self.init(status: status) { _ in translation }
    }

    convenience init(error: any Error & Sendable) {
        self.init { _ in throw error }
    }

    var texts: [String] {
        calls.withLock { $0.texts }
    }

    var statusDirections: [Direction] {
        calls.withLock { $0.statusDirections }
    }

    var translateDirections: [Direction] {
        calls.withLock { $0.translateDirections }
    }

    func status(
        from source: Language,
        to target: Language
    ) async -> LanguageAvailability.Status {
        let direction = Direction(source: source, target: target)
        calls.withLock { $0.statusDirections.append(direction) }
        return statuses[direction] ?? .unsupported
    }

    func translate(
        _ texts: [String],
        from source: Language,
        to target: Language
    ) async throws -> [String] {
        calls.withLock { calls in
            calls.texts += texts
            calls.translateDirections.append(Direction(source: source, target: target))
        }
        var translations: [String] = []
        for text in texts {
            translations.append(try await handler(text))
        }
        return translations
    }
}
