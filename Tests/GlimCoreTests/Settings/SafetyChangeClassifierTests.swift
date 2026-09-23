import Testing

@testable import GlimCore

struct SafetyChangeClassifierTests {
    let defaults = GlimSettings.safeDefaults

    func loosenings(after change: (inout GlimSettings) -> Void) -> [SettingsLoosening] {
        var changedSettings = defaults
        change(&changedSettings)
        return SafetyChangeClassifier.loosenings(from: defaults, to: changedSettings)
    }

    @Test func unchangedSettingsLoosenNothing() {
        #expect(SafetyChangeClassifier.loosenings(from: defaults, to: defaults).isEmpty)
    }

    @Test func startingLowRiskPlansWithoutApprovalLoosens() {
        var cautious = defaults
        cautious.safetyPolicy.asksOnlyBeforeDangerousSteps = false

        #expect(
            SafetyChangeClassifier.loosenings(from: cautious, to: defaults) == [
                .asksOnlyBeforeDangerousSteps
            ])
        #expect(SafetyChangeClassifier.loosenings(from: defaults, to: cautious).isEmpty)
    }

    @Test func ignoringTheKeyboardAndMouseLoosens() {
        let changes = loosenings { $0.safetyPolicy.stopsWhenPersonTakesOver = false }

        #expect(changes == [.personTakeoverIgnored])
    }

    @Test func removingAForbiddenPhraseLoosens() {
        let changes = loosenings { settings in
            settings.safetyPolicy.riskWords.forbidden.removeAll { $0 == "delete" }
        }

        #expect(changes == [.removedForbiddenPhrase("delete")])
    }

    @Test func movingAForbiddenPhraseToConfirmLoosens() {
        let changes = loosenings { settings in
            settings.safetyPolicy.riskWords.forbidden.removeAll { $0 == "replace" }
            settings.safetyPolicy.riskWords.confirm.append("replace")
        }

        #expect(changes == [.removedForbiddenPhrase("replace")])
    }

    @Test func rewritingAPhraseWithDifferentCaseIsNotALoosening() {
        let changes = loosenings { settings in
            settings.safetyPolicy.riskWords.forbidden = settings.safetyPolicy.riskWords.forbidden
                .map { $0.uppercased() }
        }

        #expect(changes.isEmpty)
    }

    @Test func addingPhrasesAndRestrictingAppsIsTightening() {
        let changes = loosenings { settings in
            settings.safetyPolicy.riskWords.forbidden.append("archive")
            settings.safetyPolicy.appTrust.tiersByBundleIdentifier["com.apple.Notes"] = .readOnly
            settings.jev.excludedBundleIdentifiers.insert("com.apple.Notes")
        }

        #expect(changes.isEmpty)
    }

    @Test func promotingAnAppLoosens() {
        let changes = loosenings { settings in
            settings.safetyPolicy.appTrust.tiersByBundleIdentifier["com.apple.Terminal"] =
                .fullControl
        }

        #expect(
            changes == [
                .appMovedToLessRestrictiveTier(
                    bundleIdentifier: "com.apple.Terminal", from: .readOnly, to: .fullControl)
            ])
    }

    @Test func unlistingANeverTouchAppLoosensToTheDefaultTier() {
        let changes = loosenings { settings in
            settings.safetyPolicy.appTrust.tiersByBundleIdentifier["com.apple.Passwords"] = nil
        }

        #expect(
            changes == [
                .appMovedToLessRestrictiveTier(
                    bundleIdentifier: "com.apple.Passwords", from: .neverTouch, to: .readOnly)
            ])
    }

    @Test func raisingTheDefaultTierLoosens() {
        let changes = loosenings { settings in
            settings.safetyPolicy.appTrust.defaultTier = .supervised
        }

        #expect(changes.contains(.defaultTierLoosened(from: .readOnly, to: .supervised)))
    }

    @Test func raisingLimitsAndShorteningSpacingLoosen() {
        let changes = loosenings { settings in
            settings.safetyPolicy.limits.maximumActionsPerTask = 50
            settings.safetyPolicy.limits.minimumSecondsBetweenActions = 0.1
        }

        #expect(
            changes == [
                .limitLoosened(.maximumActionsPerTask),
                .limitLoosened(.minimumSecondsBetweenActions),
            ])
    }

    @Test func enablingJevLoosens() {
        let changes = loosenings { settings in
            settings.jev.isEnabled = true
        }

        #expect(changes == [.jevEnabled])
    }

    @Test func removingAJevExclusionLoosens() {
        let changes = loosenings { settings in
            settings.jev.excludedBundleIdentifiers.remove("com.apple.mail")
        }

        #expect(changes == [.jevExclusionRemoved(bundleIdentifier: "com.apple.mail")])
    }

    @Test func messagingAppsAreExcludedFromJevByDefault() {
        #expect(
            defaults.jev.excludedBundleIdentifiers == [
                "com.apple.mail", "com.apple.MobileSMS", "net.whatsapp.WhatsApp",
                "com.tinyspeck.slackmacgap",
            ])
        #expect(!defaults.jev.isEnabled)
    }
}
