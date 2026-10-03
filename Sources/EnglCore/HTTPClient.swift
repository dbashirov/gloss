import Foundation

public struct HTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// HTTPClient performs GET requests; any HTTP status is returned as a response,
/// transport failures are thrown as `URLError`.
public protocol HTTPClient: Sendable {
    func get(_ url: URL) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    static let timeout: TimeInterval = 5

    private let session: URLSession

    public init(session: URLSession = makeSession()) {
        self.session = session
    }

    /// Returns a session that keeps nothing on disk: the API key travels in the URL.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    public func get(_ url: URL) async throws -> HTTPResponse {
        let (body, response) = try await session.data(for: request(for: url))
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPResponse(statusCode: http.statusCode, body: body)
    }

    func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
