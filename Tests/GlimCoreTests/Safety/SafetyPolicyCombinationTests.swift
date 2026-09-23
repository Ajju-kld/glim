import Testing

@testable import GlimCore

struct SafetyPolicyCombinationTests {
    let base = SafetyPolicy.safeDefaults

    @Test func eachAppGetsTheLowerTier() {
        var tighter = base
        tighter.appTrust.tiersByBundleIdentifier["com.apple.Notes"] = .neverTouch
        var looser = base
        looser.appTrust.tiersByBundleIdentifier["com.apple.Terminal"] = .fullControl

        let combined = tighter.combinedStrictly(with: looser)

        #expect(combined.appTrust.tier(for: .notes) == .neverTouch)
        #expect(combined.appTrust.tier(for: .terminal) == .readOnly)
    }

    @Test func planStartsWithoutApprovalOnlyWhenBothPoliciesAllowIt() {
        var cautious = base
        cautious.asksOnlyBeforeDangerousSteps = false

        #expect(!base.combinedStrictly(with: cautious).asksOnlyBeforeDangerousSteps)
        #expect(!cautious.combinedStrictly(with: base).asksOnlyBeforeDangerousSteps)
        #expect(base.combinedStrictly(with: base).asksOnlyBeforeDangerousSteps)
    }

    @Test func unlistedAppsUseTheStricterDefault() {
        var looser = base
        looser.appTrust.defaultTier = .fullControl

        #expect(base.combinedStrictly(with: looser).appTrust.tier(for: .unknownApp) == .readOnly)
    }

    @Test func phraseListsAreUnitedWithoutDuplicates() {
        var withArchive = base
        withArchive.riskWords.forbidden.append("archive")
        var withoutDelete = base
        withoutDelete.riskWords.forbidden.removeAll { $0 == "delete" }
        withoutDelete.riskWords.confirm.append("Pin")

        let combined = withArchive.combinedStrictly(with: withoutDelete)

        #expect(combined.riskWords.forbidden.contains("archive"))
        #expect(combined.riskWords.forbidden.contains("delete"))
        #expect(combined.riskWords.confirm.contains("Pin"))
        #expect(combined.riskWords.forbidden.count == Set(combined.riskWords.forbidden).count)
    }

    @Test func eachLimitIsTheStricterOne() {
        var looser = base
        looser.limits.maximumActionsPerTask = 50
        looser.limits.minimumSecondsBetweenActions = 0
        var tighter = base
        tighter.limits.maximumTypedTextLength = 100
        tighter.limits.taskTimeoutSeconds = 60

        let limits = looser.combinedStrictly(with: tighter).limits

        #expect(limits.maximumActionsPerTask == 20)
        #expect(limits.minimumSecondsBetweenActions == 0.25)
        #expect(limits.maximumTypedTextLength == 100)
        #expect(limits.taskTimeoutSeconds == 60)
    }
}
