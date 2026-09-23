import Foundation

/// A running app with a Dock icon.
public struct RunningApp: Sendable, Hashable {
    /// The display name.
    public let name: String
    /// The bundle identifier.
    public let bundleIdentifier: String
    /// The process identifier.
    public let processIdentifier: pid_t
    /// Whether it is the frontmost app.
    public let isFrontmost: Bool
    /// Where its bundle lives, when known.
    public let bundleURL: URL?

    /// Creates a running-app record.
    public init(
        name: String, bundleIdentifier: String, processIdentifier: pid_t, isFrontmost: Bool,
        bundleURL: URL?
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.isFrontmost = isFrontmost
        self.bundleURL = bundleURL
    }
}
