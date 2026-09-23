/// How one spoken request ended.
public enum TaskOutcome: Sendable, Equatable {
    /// A question was answered aloud.
    case answered(String)
    /// Every approved step ran.
    case completed
    /// A guard stopped the task; the guard popup explains why.
    case blocked(GuardViolation, stepNumber: Int?)
    /// The person cancelled the plan.
    case cancelled
    /// The kill switch tripped.
    case stopped(TripReason)
    /// Something went wrong that isn't a safety decision, such as Ollama being down.
    case failed(String)
}
