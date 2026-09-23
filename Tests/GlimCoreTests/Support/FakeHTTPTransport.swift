import Foundation
import Synchronization
import Testing

@testable import GlimCore

/// Replies to requests from a script and records every request it was asked to send.
final class FakeHTTPTransport: HTTPTransport {
    enum Reply: Sendable {
        case response(statusCode: Int, body: String)
        case responseFrom(url: String, statusCode: Int, body: String)
        case failure(URLError.Code)
    }

    enum FakeError: Error {
        case noReplyScripted
        case cannotBuildResponse
    }

    private let scriptedReplies: Mutex<[Reply]>
    private let recordedRequests = Mutex<[URLRequest]>([])

    init(replies: [Reply]) {
        scriptedReplies = Mutex(replies)
    }

    var sentRequests: [URLRequest] {
        recordedRequests.withLock { $0 }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recordedRequests.withLock { $0.append(request) }
        let reply = scriptedReplies.withLock { replies in
            replies.isEmpty ? nil : replies.removeFirst()
        }
        guard let reply, let requestURL = request.url else {
            throw FakeError.noReplyScripted
        }
        switch reply {
        case .response(let statusCode, let body):
            return try Self.makeResponse(url: requestURL, statusCode: statusCode, body: body)
        case .responseFrom(let address, let statusCode, let body):
            guard let responseURL = URL(string: address) else {
                throw FakeError.cannotBuildResponse
            }
            return try Self.makeResponse(url: responseURL, statusCode: statusCode, body: body)
        case .failure(let code):
            throw URLError(code)
        }
    }

    private static func makeResponse(
        url: URL, statusCode: Int, body: String
    ) throws -> (Data, HTTPURLResponse) {
        guard
            let response = HTTPURLResponse(
                url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            throw FakeError.cannotBuildResponse
        }
        return (Data(body.utf8), response)
    }
}

/// Decodes a request body as a JSON object for assertions.
func jsonObject(of request: URLRequest) throws -> [String: Any] {
    let body = try #require(request.httpBody)
    return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
}
