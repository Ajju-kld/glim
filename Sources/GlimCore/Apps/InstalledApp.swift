import Foundation

/// An app bundle found on disk.
public struct InstalledApp: Sendable, Hashable {
    /// The display name, such as "Code".
    public let name: String
    /// The bundle's file name without `.app`, such as "Visual Studio Code".
    public let fileName: String
    /// The bundle identifier.
    public let bundleIdentifier: String
    /// Where the bundle lives.
    public let url: URL

    /// Creates an installed-app record.
    public init(name: String, fileName: String, bundleIdentifier: String, url: URL) {
        self.name = name
        self.fileName = fileName
        self.bundleIdentifier = bundleIdentifier
        self.url = url
    }
}
