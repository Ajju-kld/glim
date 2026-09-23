import Foundation

/// An app found by name, with its verified identity and how to reach it.
public struct ResolvedApp: Sendable, Equatable {
    /// Bundle identifier, name and signature status.
    public let identity: AppIdentity
    /// Where the bundle lives, when known.
    public let bundleURL: URL?
    /// The process identifier, when the app is running.
    public let processIdentifier: pid_t?

    /// Creates a resolved app.
    public init(identity: AppIdentity, bundleURL: URL?, processIdentifier: pid_t?) {
        self.identity = identity
        self.bundleURL = bundleURL
        self.processIdentifier = processIdentifier
    }
}
