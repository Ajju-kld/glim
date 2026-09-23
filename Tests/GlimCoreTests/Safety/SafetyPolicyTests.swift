import Testing

@testable import GlimCore

struct SafetyPolicyTests {
    let defaults = SafetyPolicy.safeDefaults

    @Test func glimCanNeverActOnItself() {
        #expect(defaults.appTrust.tier(for: .glim) == .neverTouch)
    }

    @Test func passwordManagerIsNeverTouch() {
        #expect(defaults.appTrust.tier(for: .passwords) == .neverTouch)
    }

    @Test func testbedHasFullControl() {
        #expect(defaults.appTrust.tier(for: .testbed) == .fullControl)
    }

    @Test func messagingHasFullControl() {
        #expect(defaults.appTrust.tier(for: .messages) == .fullControl)
    }

    @Test(arguments: ["com.apple.Terminal", "dev.warp.Warp-Stable", "com.googlecode.iterm2"])
    func terminalsAreReadOnly(bundleIdentifier: String) {
        #expect(defaults.appTrust.tiersByBundleIdentifier[bundleIdentifier] == .readOnly)
    }

    @Test(arguments: [
        "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.apple.dt.Xcode",
        "com.anthropic.claudefordesktop", "com.openai.codex",
    ])
    func codingAndAgentAppsAreSupervised(bundleIdentifier: String) {
        #expect(defaults.appTrust.tiersByBundleIdentifier[bundleIdentifier] == .supervised)
    }

    @Test func unknownAppsAreReadOnly() {
        #expect(defaults.appTrust.tier(for: .unknownApp) == .readOnly)
    }

    @Test func tierListsDoNotOverlap() {
        let everyListedApp =
            SafetyDefaults.neverTouchBundleIdentifiers
            + SafetyDefaults.readOnlyBundleIdentifiers
            + SafetyDefaults.supervisedBundleIdentifiers
            + SafetyDefaults.fullControlBundleIdentifiers

        #expect(Set(everyListedApp).count == everyListedApp.count)
    }

    @Test(arguments: ["delete", "don't save", "allow", "buy", "sign out", "replace", "install"])
    func dangerousPhrasesAreForbidden(phrase: String) {
        #expect(defaults.riskWords.forbidden.contains(phrase))
    }

    @Test(arguments: ["send", "submit", "reply", "forward", "close"])
    func sendingPhrasesNeedConfirmation(phrase: String) {
        #expect(defaults.riskWords.confirm.contains(phrase))
    }

    @Test func limitsMatchTheSpec() {
        let limits = defaults.limits

        #expect(limits.maximumActionsPerTask == 20)
        #expect(limits.maximumTriesPerStep == 3)
        #expect(limits.minimumSecondsBetweenActions == 0.25)
        #expect(limits.taskTimeoutSeconds == 180)
        #expect(limits.maximumConsecutiveUnchangedActions == 3)
        #expect(limits.maximumTypedTextLength == 500)
    }

    @Test func limitDurationsAreDerivedFromSeconds() {
        #expect(defaults.limits.taskTimeout == .seconds(180))
        #expect(defaults.limits.minimumSpacing == .milliseconds(250))
    }
}
