/// Screens a whole plan before the person sees it, so a plan with a step that would be denied
/// is never offered for approval.
///
/// Applies the checks that don't need the live screen (spec §9.2): the app exists and its tier
/// permits the step, typed text is within the length limit and has no control characters, the
/// target description has no Forbidden phrase, and the plan is neither empty nor longer than
/// the action limit.
public struct PlanScreener: Sendable {
    private let policy: SafetyPolicy
    private let riskClassifier: RiskClassifier

    /// Creates a screener that enforces `policy`.
    public init(policy: SafetyPolicy) {
        self.policy = policy
        self.riskClassifier = RiskClassifier(wordLists: policy.riskWords)
    }

    /// Screens `plan`.
    ///
    /// - Parameters:
    ///   - plan: The plan proposed by the model.
    ///   - resolveApp: Maps an app name from the plan to a verified identity, or nil when no
    ///     such app is installed or running.
    ///   - isRunning: Whether the named app is running. A switch to an app that isn't becomes
    ///     an open, screened like any other open.
    /// - Returns: The screened plan, or the first violation and the step that caused it.
    public func screen(
        _ plan: Plan, resolveApp: (String) -> AppIdentity?,
        isRunning: (String) -> Bool = { _ in true }
    ) -> PlanScreeningOutcome {
        guard !plan.steps.isEmpty else {
            return .rejected(.emptyPlan, stepNumber: nil)
        }
        let actionLimit = policy.limits.maximumActionsPerTask
        guard plan.steps.count <= actionLimit else {
            return .rejected(.limitReached(.tooManyActions(limit: actionLimit)), stepNumber: nil)
        }
        var screenedSteps: [ScreenedStep] = []
        for (offset, plannedAction) in plan.steps.enumerated() {
            let stepNumber = offset + 1
            let action = Self.openingInsteadOfSwitching(plannedAction, isRunning: isRunning)
            do throws(GuardViolation) {
                let screenedStep = try screenStep(
                    action, number: stepNumber, resolveApp: resolveApp)
                screenedSteps.append(screenedStep)
            } catch {
                return .rejected(error, stepNumber: stepNumber)
            }
        }
        return .readyForApproval(ScreenedPlan(goal: plan.goal, steps: screenedSteps))
    }

    /// The model sometimes plans "Switch to" an app that is closed, which can't run; opening it
    /// is what the person meant.
    private static func openingInsteadOfSwitching(
        _ action: StepAction, isRunning: (String) -> Bool
    ) -> StepAction {
        guard case .switchApp(let appName) = action, !isRunning(appName) else {
            return action
        }
        return .openApp(appName: appName)
    }

    private func screenStep(
        _ action: StepAction, number: Int, resolveApp: (String) -> AppIdentity?
    ) throws(GuardViolation) -> ScreenedStep {
        guard let appName = action.appName else {
            return ScreenedStep(number: number, action: action, app: nil, tier: nil)
        }
        guard let app = resolveApp(appName) else {
            throw .unknownTarget(description: appName)
        }
        let tier = policy.appTrust.tier(for: app)
        guard AppTrustPolicy.permission(for: action.kind, in: tier) != .denied else {
            throw .blockedByTier(appName: app.displayName, tier: tier, action: action.kind)
        }
        if action.kind == .openApp, !app.hasValidSignature {
            throw .unverifiedApp(appName: app.displayName)
        }
        if let target = action.targetDescription,
            case .forbidden(let matchedPhrase) = riskClassifier.classify([target])
        {
            throw .forbiddenAction(matchedPhrase: matchedPhrase, elementLabel: target)
        }
        if let text = action.approvedText {
            try screenTypedText(text)
        }
        return ScreenedStep(number: number, action: action, app: app, tier: tier)
    }

    private func screenTypedText(_ text: String) throws(GuardViolation) {
        let lengthLimit = policy.limits.maximumTypedTextLength
        guard text.count <= lengthLimit else {
            throw .textTooLong(limit: lengthLimit)
        }
        guard !TextSafety.containsUnsafeCharacters(text) else {
            throw .unsafeText
        }
    }
}
