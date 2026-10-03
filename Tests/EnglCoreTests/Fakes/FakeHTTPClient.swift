import Foundation
import Synchronization
@testable import EnglCore

final class FakeHTTPClient: HTTPClient {
    typealias Handler = @Sendable (URL) async throws -> HTTPResponse

    private let handler: Handler
    private let received = Mutex<[URL]>([])

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    convenience init(status: Int, body: Data) {
        self.init { _ in HTTPResponse(statusCode: status, body: body) }
    }

    convenience init(status: Int = 200, json: String) {
        self.init(status: status, body: Data(json.utf8))
    }

    convenience init(error: any Error & Sendable) {
        self.init { _ in throw error }
    }

    var urls: [URL] {
        received.withLock { $0 }
    }

    func get(_ url: URL) async throws -> HTTPResponse {
        received.withLock { $0.append(url) }
        return try await handler(url)
    }
}
