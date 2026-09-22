import Foundation

/// Decides whether an app's code signature proves it is the app it claims to be.
public protocol SignatureVerifying: Sendable {
    /// Whether the app at `bundleURL` (or the running process) is signed with its claimed
    /// `bundleIdentifier` by an Apple-issued certificate.
    func hasTrustedSignature(
        bundleIdentifier: String, bundleURL: URL?, processIdentifier: pid_t?
    ) -> Bool
}
