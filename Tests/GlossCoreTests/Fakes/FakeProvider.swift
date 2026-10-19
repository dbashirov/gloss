import Synchronization
@testable import GlossCore

final class FakeProvider: TranslationProvider {
    typealias Handler = @Sendable (Query) async throws -> TranslationResult

    let id: String
    private let kinds: Set<QueryKind>
    private let handler: Handler
    private let received = Mutex<[Query]>([])

    init(
        id: String,
        kinds: Set<QueryKind> = [.dictionary, .sentence],
        handler: @escaping Handler
    ) {
        self.id = id
        self.kinds = kinds
        self.handler = handler
    }

    convenience init(
        id: String,
        kinds: Set<QueryKind> = [.dictionary, .sentence],
        result: TranslationResult
    ) {
        self.init(id: id, kinds: kinds) { _ in result }
    }

    convenience init(
        id: String,
        kinds: Set<QueryKind> = [.dictionary, .sentence],
        error: any Error & Sendable
    ) {
        self.init(id: id, kinds: kinds) { _ in throw error }
    }

    var calls: Int {
        received.withLock { $0.count }
    }

    var queries: [Query] {
        received.withLock { $0 }
    }

    func supports(_ query: Query) -> Bool {
        kinds.contains(query.kind)
    }

    func translate(_ query: Query) async throws -> TranslationResult {
        received.withLock { $0.append(query) }
        return try await handler(query)
    }
}
