import Testing

@testable import GlimCore

struct AppTrustPolicyTests {
    let policy = AppTrustPolicy(
        tiersByBundleIdentifier: [
            "com.apple.Notes": .fullControl,
            "com.apple.Passwords": .neverTouch,
            "com.todesktop.230313mzl4w4u92": .supervised,
        ],
        defaultTier: .readOnly)

    @Test func listedAppGetsItsTier() {
        #expect(policy.tier(for: .notes) == .fullControl)
        #expect(policy.tier(for: .cursor) == .supervised)
    }

    @Test func unlistedAppGetsTheDefaultTier() {
        #expect(policy.tier(for: .unknownApp) == .readOnly)
    }

    @Test func impostorOfATrustedAppIsCappedAtReadOnly() {
        #expect(policy.tier(for: .impostorNotes) == .readOnly)
    }

    @Test func impostorOfANeverTouchAppStaysNeverTouch() {
        #expect(policy.tier(for: .impostorPasswords) == .neverTouch)
    }

    @Test func tiersAreOrderedFromMostToLeastRestrictive() {
        let shuffledTiers: [TrustTier] = [.fullControl, .neverTouch, .supervised, .readOnly]

        #expect(shuffledTiers.sorted() == [.neverTouch, .readOnly, .supervised, .fullControl])
    }

    @Test(arguments: [
        (TrustTier.neverTouch, ActionKind.openApp, TierPermission.denied),
        (.neverTouch, .moveWindow, .denied),
        (.neverTouch, .click, .denied),
        (.readOnly, .openApp, .allowed),
        (.readOnly, .switchApp, .allowed),
        (.readOnly, .quitApp, .allowedWithConfirmation),
        (.readOnly, .moveWindow, .allowed),
        (.readOnly, .minimizeWindow, .allowed),
        (.readOnly, .restoreWindow, .allowed),
        (.readOnly, .click, .denied),
        (.readOnly, .typeText, .denied),
        (.readOnly, .pressKey, .denied),
        (.readOnly, .scroll, .denied),
        (.supervised, .openApp, .allowedWithConfirmation),
        (.supervised, .quitApp, .allowedWithConfirmation),
        (.supervised, .click, .allowedWithConfirmation),
        (.supervised, .typeText, .allowedWithConfirmation),
        (.supervised, .pressKey, .allowedWithConfirmation),
        (.supervised, .moveWindow, .allowedWithConfirmation),
        (.fullControl, .openApp, .allowed),
        (.fullControl, .click, .allowed),
        (.fullControl, .typeText, .allowed),
        (.fullControl, .scroll, .allowed),
        (.fullControl, .moveWindow, .allowed),
        (.fullControl, .quitApp, .allowedWithConfirmation),
    ])
    func permissionMatrixMatchesTheSpec(
        tier: TrustTier, kind: ActionKind, expectedPermission: TierPermission
    ) {
        #expect(AppTrustPolicy.permission(for: kind, in: tier) == expectedPermission)
    }
}
