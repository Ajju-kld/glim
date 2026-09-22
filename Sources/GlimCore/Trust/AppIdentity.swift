/// An application as trust decisions see it: bundle identifier plus signature status.
///
/// A display name alone is never trusted, because any app can call itself "Notes".
public struct AppIdentity: Sendable, Hashable {
    /// The app's bundle identifier, such as `com.apple.Notes`.
    public let bundleIdentifier: String
    /// The name shown to the person.
    public let displayName: String
    /// Whether macOS validated the app's code signature. Unverified apps are capped at read-only.
    public let hasValidSignature: Bool

    /// Creates an identity. Callers verify the signature before passing `true`.
    public init(bundleIdentifier: String, displayName: String, hasValidSignature: Bool) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.hasValidSignature = hasValidSignature
    }
}
