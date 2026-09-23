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

    /// One readable line for the activity log.
    public var summary: String {
        switch self {
        case .answered(let answer): "answered: \(answer)"
        case .completed: "completed"
        case .blocked(let violation, let stepNumber):
            "blocked\(stepNumber.map { " at step \($0)" } ?? ""): \(violation.title) — \(violation.explanation)"
        case .cancelled: "cancelled"
        case .stopped(let reason): "stopped: \(reason.explanation)"
        case .failed(let message): "failed: \(message)"
        }
    }
}
