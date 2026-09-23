import Testing

@testable import GlimCore

struct LowRiskPlanRuleTests {
    let policy = SafetyPolicy.safeDefaults

    func screenedPlan(goal: String, _ steps: [(StepAction, AppIdentity?)]) -> ScreenedPlan {
        ScreenedPlan(
            goal: goal,
            steps: steps.enumerated().map { offset, step in
                let (action, app) = step
                return ScreenedStep(
                    number: offset + 1, action: action, app: app,
                    tier: app.map(policy.appTrust.tier(for:)))
            })
    }

    func startsWithoutApproval(_ plan: ScreenedPlan, policy customPolicy: SafetyPolicy? = nil)
        -> Bool
    {
        LowRiskPlanRule.startsWithoutApproval(plan, policy: customPolicy ?? policy)
    }

    @Test func openingAndWritingInAFullControlAppStartsAtOnce() {
        let plan = screenedPlan(
            goal: "open notes and write buy milk",
            [
                (.openApp(appName: "Notes"), .notes),
                (.click(appName: "Notes", target: "New Note"), .notes),
                (.typeText(appName: "Notes", target: "note body", text: "buy milk"), .notes),
            ])

        #expect(startsWithoutApproval(plan))
    }

    @Test func turnedOffAlwaysShowsThePlan() {
        var cautiousPolicy = policy
        cautiousPolicy.autoRunsLowRiskPlans = false
        let plan = screenedPlan(goal: "open notes", [(.openApp(appName: "Notes"), .notes)])

        #expect(!startsWithoutApproval(plan, policy: cautiousPolicy))
    }

    @Test func arrangingReadOnlyAppsStartsAtOnce() {
        let plan = screenedPlan(
            goal: "put terminal on the left and minimize it",
            [
                (.moveWindow(appName: "Terminal", preset: .leftHalf), .terminal),
                (.minimizeWindow(appName: "Terminal"), .terminal),
            ])

        #expect(startsWithoutApproval(plan))
    }

    @Test func speakingStartsAtOnce() {
        let plan = screenedPlan(goal: "say hello", [(.speak(text: "Hello"), nil)])

        #expect(startsWithoutApproval(plan))
    }

    @Test(arguments: [
        (StepAction.click(appName: "Cursor", target: "Run"), AppIdentity.cursor),
        (.quitApp(appName: "Notes"), .notes),
        (.pressKey(appName: "Notes", key: .returnKey), .notes),
        (.click(appName: "Messages", target: "Send"), .messages),
        (.click(appName: "Notes", target: "Share"), .notes),
    ])
    func stepThatWouldAskShowsThePlanFirst(action: StepAction, app: AppIdentity) {
        let plan = screenedPlan(
            goal: "do it", [(.openApp(appName: app.displayName), app), (action, app)])

        #expect(!startsWithoutApproval(plan))
    }

    @Test func harmlessKeyStartsAtOnce() {
        let plan = screenedPlan(
            goal: "press tab in notes", [(.pressKey(appName: "Notes", key: .tab), .notes)])

        #expect(startsWithoutApproval(plan))
    }

    /// Text the person didn't say came from the model or the screen, so they see it first.
    @Test func textThePersonDidNotSayShowsThePlanFirst() {
        let plan = screenedPlan(
            goal: "write a shopping note",
            [(.typeText(appName: "Notes", target: "note body", text: "buy milk"), .notes)])

        #expect(!startsWithoutApproval(plan))
    }

    @Test func spokenTextMatchesIgnoringCaseAndAccents() {
        let plan = screenedPlan(
            goal: "Write Café Order in notes",
            [(.typeText(appName: "Notes", target: "note body", text: "cafe order"), .notes)])

        #expect(startsWithoutApproval(plan))
    }
}
