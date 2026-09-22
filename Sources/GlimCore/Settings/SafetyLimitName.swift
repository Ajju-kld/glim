/// Names of the numeric safety limits, for reporting which one a change loosened.
public enum SafetyLimitName: String, Sendable, Equatable, CaseIterable {
    case maximumActionsPerTask
    case maximumTriesPerStep
    case minimumSecondsBetweenActions
    case taskTimeoutSeconds
    case maximumConsecutiveUnchangedActions
    case maximumTypedTextLength

    /// Name shown in the Touch ID prompt and the control panel.
    public var displayName: String {
        switch self {
        case .maximumActionsPerTask: "actions per task"
        case .maximumTriesPerStep: "tries per step"
        case .minimumSecondsBetweenActions: "pause between actions"
        case .taskTimeoutSeconds: "task time limit"
        case .maximumConsecutiveUnchangedActions: "actions with no visible change"
        case .maximumTypedTextLength: "longest typed text"
        }
    }
}
