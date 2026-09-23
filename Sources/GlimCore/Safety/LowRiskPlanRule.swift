import Foundation

/// Decides whether a screened plan may start without the approval panel.
///
/// A plan starts at once only when nothing in it would ask the person anyway: every step's
/// app tier allows it without confirmation (so no supervised apps and no quitting), no key is
/// Return, no target description contains a Confirm phrase, and any text to type is something
/// the person said. Text the person didn't say came from the model or the screen, so they see
/// it before it is typed. Every step still passes the full safety gate while it runs, and a
/// risky control found on screen still asks.
public enum LowRiskPlanRule {
    /// Whether `plan` may start without asking, under `policy`.
    public static func startsWithoutApproval(_ plan: ScreenedPlan, policy: SafetyPolicy) -> Bool {
        guard policy.autoRunsLowRiskPlans else {
            return false
        }
        let riskClassifier = RiskClassifier(wordLists: policy.riskWords)
        return plan.steps.allSatisfy { step in
            isLowRisk(step, goal: plan.goal, riskClassifier: riskClassifier)
        }
    }

    private static func isLowRisk(
        _ step: ScreenedStep, goal: String, riskClassifier: RiskClassifier
    ) -> Bool {
        if let tier = step.tier,
            AppTrustPolicy.permission(for: step.action.kind, in: tier) != .allowed
        {
            return false
        }
        if case .pressKey(_, .returnKey) = step.action {
            return false
        }
        if let target = step.action.targetDescription,
            riskClassifier.classify([target]) != .safe
        {
            return false
        }
        if let text = step.action.approvedText,
            goal.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) == nil
        {
            return false
        }
        return true
    }
}
