@testable import GlimCore

extension AppIdentity {
    static let notes = AppIdentity(
        bundleIdentifier: "com.apple.Notes", displayName: "Notes", hasValidSignature: true)
    static let messages = AppIdentity(
        bundleIdentifier: "com.apple.MobileSMS", displayName: "Messages", hasValidSignature: true)
    static let terminal = AppIdentity(
        bundleIdentifier: "com.apple.Terminal", displayName: "Terminal", hasValidSignature: true)
    static let cursor = AppIdentity(
        bundleIdentifier: "com.todesktop.230313mzl4w4u92", displayName: "Cursor",
        hasValidSignature: true)
    static let passwords = AppIdentity(
        bundleIdentifier: "com.apple.Passwords", displayName: "Passwords", hasValidSignature: true)
    static let glim = AppIdentity(
        bundleIdentifier: "dev.straxs.Glim", displayName: "Glim", hasValidSignature: true)
    static let testbed = AppIdentity(
        bundleIdentifier: "dev.straxs.Glim.Testbed", displayName: "Testbed", hasValidSignature: true
    )
    static let unknownApp = AppIdentity(
        bundleIdentifier: "com.example.Unknown", displayName: "Unknown", hasValidSignature: true)
    /// Claims to be Notes, but its code signature did not validate.
    static let impostorNotes = AppIdentity(
        bundleIdentifier: "com.apple.Notes", displayName: "Notes", hasValidSignature: false)
    /// Claims to be Passwords, but its code signature did not validate.
    static let impostorPasswords = AppIdentity(
        bundleIdentifier: "com.apple.Passwords", displayName: "Passwords", hasValidSignature: false)
}
