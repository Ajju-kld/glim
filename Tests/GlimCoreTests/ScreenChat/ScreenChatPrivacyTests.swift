import Testing

@testable import GlimCore

/// A whole-screen picture for screen chat leaves out never-touch apps and Glim itself.
struct ScreenChatPrivacyTests {
    let privacy = ScreenChatPrivacy(
        policy: .safeDefaults, glimBundleIdentifiers: ["dev.straxs.Glim"])

    @Test(arguments: ["com.apple.Passwords", "com.apple.keychainaccess", "com.apple.loginwindow"])
    func neverTouchAppsAreLeftOut(bundleIdentifier: String) {
        #expect(privacy.leavesOut(bundleIdentifier: bundleIdentifier))
    }

    @Test func glimsOwnGlowAndPillAreLeftOut() {
        #expect(privacy.leavesOut(bundleIdentifier: "dev.straxs.Glim"))
    }

    @Test(arguments: ["com.google.Chrome", "com.apple.Notes", "dev.straxs.Glim.Testbed"])
    func otherAppsAreInThePicture(bundleIdentifier: String) {
        #expect(!privacy.leavesOut(bundleIdentifier: bundleIdentifier))
    }

    /// An app the owner moved to never-touch is left out from then on.
    @Test func ownersNeverTouchChoiceIsRespected() {
        var policy = SafetyPolicy.safeDefaults
        policy.appTrust.tiersByBundleIdentifier["net.whatsapp.WhatsApp"] = .neverTouch

        #expect(
            ScreenChatPrivacy(policy: policy, glimBundleIdentifiers: [])
                .leavesOut(bundleIdentifier: "net.whatsapp.WhatsApp"))
    }

    /// With never-touch as the default tier, every app not given a tier is left out.
    @Test func neverTouchDefaultLeavesOutUnlistedApps() {
        var policy = SafetyPolicy.safeDefaults
        policy.appTrust.defaultTier = .neverTouch

        #expect(
            ScreenChatPrivacy(policy: policy, glimBundleIdentifiers: [])
                .leavesOut(bundleIdentifier: "com.example.Unlisted"))
    }
}
