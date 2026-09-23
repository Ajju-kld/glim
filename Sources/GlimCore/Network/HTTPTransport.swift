import Foundation

/// Sends one HTTP request. Clients depend on this protocol so tests can script replies.
public protocol HTTPTransport: Sendable {
    /// Sends `request` and returns the body and response.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
