import Foundation

/// The single choke point for Glim's network traffic: every request is checked against the
/// ``NetworkPolicy`` before it is sent, and every response must come from the address that
/// was requested.
public struct PolicyEnforcingTransport: HTTPTransport {
    private let base: any HTTPTransport
    private let policy: NetworkPolicy

    /// Wraps `base`, which only ever sees requests that `policy` allows.
    public init(base: any HTTPTransport, policy: NetworkPolicy) {
        self.base = base
        self.policy = policy
    }

    /// Validates, sends, then checks the response address.
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let requestURL = request.url else {
            throw NetworkPolicyError.notAllowed(url: "")
        }
        try policy.validate(requestURL)
        let (data, response) = try await base.send(request)
        if let responseURL = response.url, responseURL != requestURL {
            throw HTTPTransportError.redirectRefused(to: responseURL.absoluteString)
        }
        return (data, response)
    }
}
