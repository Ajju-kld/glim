import Testing

@testable import GlimCore

struct PlanScreenerTests {
    let screener = PlanScreener(policy: .safeDefaults)
    let knownApps: [String: AppIdentity] = [
        "Notes": .notes, "Terminal": .terminal, "Cursor": .cursor, "Passwords": .passwords,
        "Messages": .messages,
    ]

    func screen(_ steps: [StepAction]) -> PlanScreeningOutcome {
        screener.screen(Plan(goal: "test goal", steps: steps)) { appName in
            knownApps[appName]
        }
    }

    @Test func safePlanIsReadyForApprovalWithVerifiedAppsAndTiers() throws {
        let outcome = screen([
            .openApp(appName: "Notes"),
            .click(appName: "Notes", target: "New Note"),
            .typeText(appName: "Notes", target: "note body", text: "buy milk"),
        ])

        guard case .readyForApproval(let screenedPlan) = outcome else {
            Issue.record("Expected a plan ready for approval, got \(outcome)")
            return
        }
        #expect(screenedPlan.goal == "test goal")
        #expect(screenedPlan.steps.map(\.number) == [1, 2, 3])
        #expect(screenedPlan.steps.allSatisfy { $0.app == .notes && $0.tier == .fullControl })
    }

    @Test func speakStepNeedsNoApp() {
        guard case .readyForApproval(let screenedPlan) = screen([.speak(text: "Hello")]) else {
            Issue.record("Expected a plan ready for approval")
            return
        }
        #expect(screenedPlan.steps.first?.app == nil)
    }

    @Test func readOnlyAppCanBeOpenedAndArranged() {
        let outcome = screen([
            .openApp(appName: "Terminal"),
            .moveWindow(appName: "Terminal", preset: .leftHalf),
            .minimizeWindow(appName: "Terminal"),
        ])

        guard case .readyForApproval = outcome else {
            Issue.record("Expected a plan ready for approval, got \(outcome)")
            return
        }
    }

    @Test func supervisedStepsAreShownForApproval() {
        guard
            case .readyForApproval(let screenedPlan) = screen([
                .click(appName: "Cursor", target: "Run")
            ])
        else {
            Issue.record("Expected a plan ready for approval")
            return
        }
        #expect(screenedPlan.steps.first?.tier == .supervised)
    }

    @Test func unknownAppIsRejected() {
        #expect(
            screen([.openApp(appName: "Photoshop")])
                == .rejected(.unknownTarget(description: "Photoshop"), stepNumber: 1))
    }

    @Test func clickInReadOnlyAppIsRejectedBeforeApproval() {
        #expect(
            screen([.openApp(appName: "Terminal"), .click(appName: "Terminal", target: "Run")])
                == .rejected(
                    .blockedByTier(appName: "Terminal", tier: .readOnly, action: .click),
                    stepNumber: 2))
    }

    @Test func neverTouchAppCannotEvenBeOpened() {
        #expect(
            screen([.openApp(appName: "Passwords")])
                == .rejected(
                    .blockedByTier(appName: "Passwords", tier: .neverTouch, action: .openApp),
                    stepNumber: 1))
    }

    @Test func forbiddenTargetIsRejectedBeforeApproval() {
        #expect(
            screen([.openApp(appName: "Notes"), .click(appName: "Notes", target: "Delete Note")])
                == .rejected(
                    .forbiddenAction(matchedPhrase: "delete", elementLabel: "Delete Note"),
                    stepNumber: 2))
    }

    @Test func typedLineBreakIsRejectedBeforeApproval() {
        #expect(
            screen([.typeText(appName: "Messages", target: "message", text: "on my way\n")])
                == .rejected(.unsafeText, stepNumber: 1))
    }

    @Test func overlongTextIsRejectedBeforeApproval() {
        let limit = SafetyLimits.safeDefaults.maximumTypedTextLength
        let longText = String(repeating: "a", count: limit + 1)

        #expect(
            screen([.typeText(appName: "Notes", target: "body", text: longText)])
                == .rejected(.textTooLong(limit: limit), stepNumber: 1))
    }

    @Test func emptyPlanIsRejected() {
        #expect(screen([]) == .rejected(.emptyPlan, stepNumber: nil))
    }

    @Test func planLongerThanTheActionLimitIsRejected() {
        let limit = SafetyLimits.safeDefaults.maximumActionsPerTask
        let tooManySteps = Array(repeating: StepAction.speak(text: "hi"), count: limit + 1)

        #expect(
            screen(tooManySteps)
                == .rejected(.limitReached(.tooManyActions(limit: limit)), stepNumber: nil))
    }
}

struct PlanScreenerSignatureTests {
    @Test func openingAnUnverifiedAppIsRejectedBeforeApproval() {
        let screener = PlanScreener(policy: .safeDefaults)

        let outcome = screener.screen(Plan(goal: "open notes", steps: [.openApp(appName: "Notes")]))
        { _ in
            .impostorNotes
        }

        #expect(outcome == .rejected(.unverifiedApp(appName: "Notes"), stepNumber: 1))
    }
}
