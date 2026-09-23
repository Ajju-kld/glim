/// A safety limit that stops a task.
public enum LimitViolation: Sendable, Equatable {
    case tooManyActions(limit: Int)
    case tooManyTriesForStep(limit: Int)
    case actionsTooClose(minimumSeconds: Double)
    case taskTimedOut(limitSeconds: Double)
    case noVisibleChange(limit: Int)

    /// One sentence for the guard popup.
    public var explanation: String {
        switch self {
        case .tooManyActions(let limit):
            "The task reached its limit of \(limit) actions."
        case .tooManyTriesForStep(let limit):
            "The AI failed to pick a valid target \(limit) times for this step."
        case .actionsTooClose(let minimumSeconds):
            "Actions must be at least \(minimumSeconds) seconds apart."
        case .taskTimedOut(let limitSeconds):
            "The task ran longer than \(Int(limitSeconds)) seconds."
        case .noVisibleChange(let limit):
            "\(limit) actions in a row changed nothing on screen."
        }
    }
}
