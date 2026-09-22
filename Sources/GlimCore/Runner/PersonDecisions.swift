/// Asks the person to approve plans and confirm risky steps. The live implementation shows the
/// centered panels; approval is by mouse click only, never by voice.
public protocol PersonDecisions: Sendable {
    /// Shows the plan; returns true only if the person clicked Approve before the timeout.
    func approvePlan(_ plan: ScreenedPlan) async -> Bool
    /// Shows the confirmation panel; returns true only if the person clicked Allow once.
    func confirmAction(_ request: ConfirmationRequest) async -> Bool
}
