import Foundation

/// The live transport: an ephemeral session (no cookies, no cache) that never follows redirects.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession
    private let redirectRefuser = RedirectRefuser()

    /// Creates a transport with its own ephemeral session that ignores system proxies, so
    /// traffic goes only where the network allowlist says. Create one and share it.
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        session = URLSession(configuration: configuration)
    }

    /// Sends `request`; a redirect is returned as-is instead of being followed.
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request, delegate: redirectRefuser)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPTransportError.notHTTPResponse
        }
        return (data, httpResponse)
    }
}

/// Refuses every HTTP redirect, so a server can't bounce a request outside the allowlist.
private final class RedirectRefuser: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
