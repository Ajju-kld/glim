import Foundation

/// One of the only network endpoints Glim may contact (spec §9.11).
public struct NetworkEndpoint: Sendable, Hashable {
    /// Local Ollama server. A literal loopback address, so no name lookup can redirect it.
    public static let ollama = NetworkEndpoint(scheme: "http", host: "127.0.0.1", port: 11_434)
    /// Local Laya decision service.
    public static let layaService = NetworkEndpoint(scheme: "http", host: "127.0.0.1", port: 8791)
    /// TypeSafe's hosted Jev API; only reachable while the person has Jev switched on.
    public static let jev = NetworkEndpoint(scheme: "https", host: "api.typesafe.ai", port: 443)

    /// `http` or `https`.
    public let scheme: String
    /// Host name or literal address.
    public let host: String
    /// TCP port.
    public let port: Int

    /// Creates an endpoint description. Being described does not make it allowed; only
    /// ``NetworkPolicy`` decides that.
    public init(scheme: String, host: String, port: Int) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    /// The URL for `path` on this endpoint.
    ///
    /// - Parameter path: An absolute path such as `/api/chat`.
    /// - Returns: The full URL.
    /// - Throws: ``NetworkPolicyError/invalidURL(path:)`` when `path` does not form a valid URL.
    public func url(path: String) throws(NetworkPolicyError) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        components.path = path
        guard let url = components.url else {
            throw .invalidURL(path: path)
        }
        return url
    }
}
