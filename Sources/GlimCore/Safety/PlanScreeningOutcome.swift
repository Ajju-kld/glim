/// The result of screening a whole plan before the approval panel.
public enum PlanScreeningOutcome: Sendable, Equatable {
    /// Every step passed; show the plan for approval.
    case readyForApproval(ScreenedPlan)
    /// A step (or the plan as a whole, when `stepNumber` is nil) would be denied; the task stops
    /// with the guard popup and the plan is never shown for approval.
    case rejected(GuardViolation, stepNumber: Int?)
}
