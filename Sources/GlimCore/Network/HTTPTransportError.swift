/// Transport-level failures.
public enum HTTPTransportError: Error, Sendable, Equatable {
    /// The server answered with something other than HTTP.
    case notHTTPResponse
    /// The response came from a different address than the one requested — a redirect Glim
    /// refuses to follow, because it could lead outside the network allowlist.
    case redirectRefused(to: String)
}
