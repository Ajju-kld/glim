/// Progress the runner reports to the interface (the notch pill and panels).
public enum TaskEvent: Sendable, Equatable {
    /// Planning or answering is in progress.
    case thinking
    /// The plan waits for the person's approval.
    case awaitingPlanApproval(ScreenedPlan)
    /// A step is running.
    case acting(stepNumber: Int, totalSteps: Int, summary: String)
    /// A step waits for the person's confirmation.
    case awaitingConfirmation(ConfirmationRequest)
    /// The request ended.
    case finished(TaskOutcome)
}
