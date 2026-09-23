import CoreGraphics
import Testing

@testable import GlimCore

/// The gate's rules for a click Glim found by sight instead of reading a labelled control.
struct SafetyGateVisualClickTests {
    let gate = SafetyGate(policy: .safeDefaults)
    let windowFrame = CGRect(x: 0, y: 0, width: 1_000, height: 800)

    func clickBySight(
        in app: AppIdentity = .notes, target plannedTarget: String = "Play",
        gridX: Int = 500, gridY: Int = 500, description: String = "Play button"
    ) -> GateContext {
        makeGateContext(
            step: .click(appName: app.displayName, target: plannedTarget),
            stepApp: app,
            proposedAction: ProposedAction(
                kind: .click, targetApp: app,
                visualTarget: VisualTarget(
                    windowFrame: windowFrame, gridX: gridX, gridY: gridY,
                    description: description)))
    }

    /// Asking only before danger still asks: nothing on screen was read, so only the person
    /// can check the spot.
    @Test func clickBySightAlwaysAsks() {
        #expect(
            gate.evaluate(clickBySight())
                == .needsConfirmation([.visualClick(description: "Play button")]))
    }

    @Test func clickBySightIsADangerReason() {
        #expect(ConfirmationReason.visualClick(description: "Play button").isDangerous)
    }

    @Test func pointInTheTitleBarIsDenied() {
        #expect(
            gate.evaluate(clickBySight(gridY: 0))
                == .deny(.visualTargetOutsideWindow(description: "Play button")))
    }

    @Test func pointOutsideTheWindowIsDenied() {
        #expect(
            gate.evaluate(clickBySight(gridX: 1_200))
                == .deny(.visualTargetOutsideWindow(description: "Play button")))
    }

    @Test func forbiddenWordInWhatTheModelSawIsDenied() {
        #expect(
            gate.evaluate(clickBySight(target: "the icon", description: "Delete Account"))
                == .deny(
                    .forbiddenAction(matchedPhrase: "delete", elementLabel: "Delete Account")))
    }

    @Test func riskyWordInWhatTheModelSawAddsItsReason() {
        #expect(
            gate.evaluate(clickBySight(target: "the arrow", description: "Send"))
                == .needsConfirmation([
                    .riskyWord(matchedPhrase: "send", elementLabel: "Send"),
                    .visualClick(description: "Send"),
                ]))
    }

    @Test func tierThatForbidsClicksForbidsThemBySightToo() {
        #expect(
            gate.evaluate(clickBySight(in: .passwords))
                == .deny(.blockedByTier(appName: "Passwords", tier: .neverTouch, action: .click)))
    }

    /// Sight is only for clicks: typing needs a field the gate can check.
    @Test func typingAtAPointFoundBySightIsDenied() {
        let context = makeGateContext(
            step: .typeText(appName: "Notes", target: "note body", text: "hi"),
            proposedAction: ProposedAction(
                kind: .typeText, targetApp: .notes, text: "hi",
                visualTarget: VisualTarget(
                    windowFrame: windowFrame, gridX: 500, gridY: 500, description: "Note body")))

        #expect(gate.evaluate(context) == .deny(.unknownTarget(description: "note body")))
    }
}
