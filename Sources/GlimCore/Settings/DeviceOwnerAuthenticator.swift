import LocalAuthentication
import os

/// Confirms the owner with Touch ID, or the Mac password when Touch ID isn't available.
public struct DeviceOwnerAuthenticator: OwnerAuthenticating {
    private static let logger = Logger(
        subsystem: "dev.straxs.Glim", category: "OwnerAuthentication")

    /// Creates the authenticator.
    public init() {}

    /// Shows the system prompt with `reason`; a cancel or failure means "not confirmed".
    public func confirmOwner(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            Self.logger.notice(
                "Owner confirmation not given: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
