/// Confirms the Mac's owner is present before safety settings are loosened. The live
/// implementation uses Touch ID or the Mac password.
public protocol OwnerAuthenticating: Sendable {
    /// Asks the owner to confirm.
    ///
    /// - Parameter reason: Shown in the system prompt, such as "stop forbidding “delete”".
    /// - Returns: `true` only if the owner authenticated.
    func confirmOwner(reason: String) async -> Bool
}
