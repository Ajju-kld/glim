import Foundation

/// Refuses every outgoing request except to Glim's allowed endpoints.
///
/// Glim is not sandboxed (the sandbox would block the Accessibility API), so this check is what
/// keeps screen content on the Mac. Every client validates its URL here before sending.
public struct NetworkPolicy: Sendable {
    private static let defaultPortsByScheme = ["http": 80, "https": 443]

    private let allowedEndpoints: Set<NetworkEndpoint>

    /// Creates a policy; Jev is reachable only when `isJevEnabled` is true.
    public init(isJevEnabled: Bool) {
        var endpoints: Set<NetworkEndpoint> = [.ollama, .layaService]
        if isJevEnabled {
            endpoints.insert(.jev)
        }
        allowedEndpoints = endpoints
    }

    /// Throws unless `url` points exactly at an allowed endpoint: same scheme, host and port,
    /// and no user name or password.
    public func validate(_ url: URL) throws(NetworkPolicyError) {
        guard url.user(percentEncoded: false) == nil,
            url.password(percentEncoded: false) == nil,
            let scheme = url.scheme?.lowercased(),
            let host = url.host(percentEncoded: false)?.lowercased(),
            let port = url.port ?? Self.defaultPortsByScheme[scheme]
        else {
            throw .notAllowed(url: url.absoluteString)
        }
        let endpoint = NetworkEndpoint(scheme: scheme, host: host, port: port)
        guard allowedEndpoints.contains(endpoint) else {
            if endpoint == .jev {
                throw .jevDisabled
            }
            throw .notAllowed(url: url.absoluteString)
        }
    }
}
