/// Numeric limits that stop a task before it can run away.
public struct SafetyLimits: Sendable, Equatable, Codable {
    /// The limits from the design spec (§9.2, check 7).
    public static let safeDefaults = SafetyLimits(
        maximumActionsPerTask: 20,
        maximumTriesPerStep: 3,
        minimumSecondsBetweenActions: 0.25,
        taskTimeoutSeconds: 180,
        maximumConsecutiveUnchangedActions: 3,
        maximumTypedTextLength: 500)

    /// Business rule: a task that needs more actions than this is probably off track.
    public var maximumActionsPerTask: Int
    /// Business rule: model errors tolerated for one step before the task is blocked.
    public var maximumTriesPerStep: Int
    /// Tunable: pause between actions so apps can react and a person can follow along.
    public var minimumSecondsBetweenActions: Double
    /// Business rule: deadline for a whole task.
    public var taskTimeoutSeconds: Double
    /// Business rule: actions in a row that change nothing on screen before the task is blocked.
    public var maximumConsecutiveUnchangedActions: Int
    /// Business rule: longest text Glim may type in one step.
    public var maximumTypedTextLength: Int

    /// Creates limits.
    public init(
        maximumActionsPerTask: Int,
        maximumTriesPerStep: Int,
        minimumSecondsBetweenActions: Double,
        taskTimeoutSeconds: Double,
        maximumConsecutiveUnchangedActions: Int,
        maximumTypedTextLength: Int
    ) {
        self.maximumActionsPerTask = maximumActionsPerTask
        self.maximumTriesPerStep = maximumTriesPerStep
        self.minimumSecondsBetweenActions = minimumSecondsBetweenActions
        self.taskTimeoutSeconds = taskTimeoutSeconds
        self.maximumConsecutiveUnchangedActions = maximumConsecutiveUnchangedActions
        self.maximumTypedTextLength = maximumTypedTextLength
    }

    /// The task deadline as a duration.
    public var taskTimeout: Duration {
        .seconds(taskTimeoutSeconds)
    }

    /// The minimum spacing between actions as a duration.
    public var minimumSpacing: Duration {
        .seconds(minimumSecondsBetweenActions)
    }
}
