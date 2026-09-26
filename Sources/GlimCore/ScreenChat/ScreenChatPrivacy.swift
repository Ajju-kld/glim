/// Which apps a whole-screen picture for screen chat leaves out: every never-touch app, and
/// Glim's own windows (the glow and the pill). Left-out apps are removed by the capture itself,
/// so their pixels never reach Glim.
public struct ScreenChatPrivacy: Sendable {
    private let appTrust: AppTrustPolicy
    private let glimBundleIdentifiers: Set<String>

    /// Creates the rule for `policy`, also leaving out the apps in `glimBundleIdentifiers`.
    public init(policy: SafetyPolicy, glimBundleIdentifiers: Set<String>) {
        appTrust = policy.appTrust
        self.glimBundleIdentifiers = glimBundleIdentifiers
    }

    /// Whether the app with `bundleIdentifier` is left out of the picture. A signature that
    /// didn't validate only ever lowers an app's tier, so it is looked up as verified here: that
    /// can't bring a never-touch app back into the picture.
    public func leavesOut(bundleIdentifier: String) -> Bool {
        if glimBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }
        let identity = AppIdentity(
            bundleIdentifier: bundleIdentifier, displayName: bundleIdentifier,
            hasValidSignature: true)
        return appTrust.tier(for: identity) == .neverTouch
    }
}
