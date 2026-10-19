import Foundation
import Synchronization
import Testing
@testable import GlossCore

@Suite(.serialized)
struct URLSessionHTTPClientTests {
    private let url = URL(string: "https://dictionary.test/lookup?text=run")!

    private func makeClient(_ handler: @escaping StubURLProtocol.Handler) -> URLSessionHTTPClient {
        StubURLProtocol.handler.withLock { $0 = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSessionHTTPClient(session: URLSession(configuration: configuration))
    }

    private func response(_ request: URLRequest, status: Int) throws -> URLResponse {
        let url = try #require(request.url)
        return try #require(HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        ))
    }

    @Test func buildsGetRequestWithTimeout() throws {
        let request = URLSessionHTTPClient().request(for: url)

        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 5)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func returnsAnyStatusWithBody() async throws {
        let requests = Mutex<[URLRequest]>([])
        let client = makeClient { request in
            requests.withLock { $0.append(request) }
            return (try response(request, status: 401), Data("denied".utf8))
        }

        let result = try await client.get(url)

        #expect(result == HTTPResponse(statusCode: 401, body: Data("denied".utf8)))
        let request = try #require(requests.withLock { $0.first })
        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 5)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func throwsTransportError() async {
        let client = makeClient { _ in throw URLError(.notConnectedToInternet) }

        await #expect {
            try await client.get(url)
        } throws: { error in
            (error as? URLError)?.code == .notConnectedToInternet
        }
    }

    @Test func rejectsNonHTTPResponse() async {
        let client = makeClient { request in
            let response = URLResponse(
                url: request.url ?? url,
                mimeType: "application/json",
                expectedContentLength: 2,
                textEncodingName: nil
            )
            return (response, Data("{}".utf8))
        }

        await #expect {
            try await client.get(url)
        } throws: { error in
            (error as? URLError)?.code == .badServerResponse
        }
    }

    @Test func defaultSessionKeepsNothingOnDisk() {
        let configuration = URLSessionHTTPClient.makeSession().configuration

        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }
}
