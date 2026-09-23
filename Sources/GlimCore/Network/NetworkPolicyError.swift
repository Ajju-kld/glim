/// Why an outgoing request was refused.
public enum NetworkPolicyError: Error, Sendable, Equatable {
    /// The address is not one of Glim's allowed endpoints.
    case notAllowed(url: String)
    /// The address is Jev's, but the person has not switched Jev on.
    case jevDisabled
    /// A request path could not form a valid URL.
    case invalidURL(path: String)
}
