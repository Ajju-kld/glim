/// Tracks one task's actions and reports when a safety limit is hit.
///
/// Time is passed in rather than read from a clock, so tests control it exactly.
public struct ActionLimiter: Sendable {
    private var limits: SafetyLimits
    private let taskStartedAt: ContinuousClock.Instant
    private var lastActionAt: ContinuousClock.Instant?

    /// Actions performed so far in this task.
    public private(set) var actionsPerformed = 0
    /// Model errors for the current step.
    public private(set) var triesForCurrentStep = 0
    /// Actions in a row that changed nothing on screen.
    public private(set) var consecutiveUnchangedActions = 0

    /// Starts tracking a task that began at `taskStartedAt`.
    public init(limits: SafetyLimits, taskStartedAt: ContinuousClock.Instant) {
        self.limits = limits
        self.taskStartedAt = taskStartedAt
    }

    /// The first limit that forbids another action at `now`, or nil when the next action may run.
    public func violation(at now: ContinuousClock.Instant) -> LimitViolation? {
        if now - taskStartedAt >= limits.taskTimeout {
            return .taskTimedOut(limitSeconds: limits.taskTimeoutSeconds)
        }
        if actionsPerformed >= limits.maximumActionsPerTask {
            return .tooManyActions(limit: limits.maximumActionsPerTask)
        }
        if triesForCurrentStep >= limits.maximumTriesPerStep {
            return .tooManyTriesForStep(limit: limits.maximumTriesPerStep)
        }
        if consecutiveUnchangedActions >= limits.maximumConsecutiveUnchangedActions {
            return .noVisibleChange(limit: limits.maximumConsecutiveUnchangedActions)
        }
        if waitBeforeNextAction(at: now) > .zero {
            return .actionsTooClose(minimumSeconds: limits.minimumSecondsBetweenActions)
        }
        return nil
    }

    /// How long the runner must wait at `now` so the next action respects the spacing limit.
    public func waitBeforeNextAction(at now: ContinuousClock.Instant) -> Duration {
        guard let lastActionAt else {
            return .zero
        }
        let remainingWait = limits.minimumSpacing - (now - lastActionAt)
        return max(remainingWait, .zero)
    }

    /// Records a performed action and whether the screen visibly changed afterwards.
    public mutating func recordAction(at now: ContinuousClock.Instant, changedScreen: Bool) {
        actionsPerformed += 1
        lastActionAt = now
        consecutiveUnchangedActions = changedScreen ? 0 : consecutiveUnchangedActions + 1
    }

    /// Records a model error (bad JSON, unknown element number) for the current step.
    public mutating func recordModelError() {
        triesForCurrentStep += 1
    }

    /// Adopts limits tightened during the task.
    public mutating func updateLimits(_ newLimits: SafetyLimits) {
        limits = newLimits
    }

    /// Resets the per-step try count when the runner moves to the next plan step.
    public mutating func beginNextStep() {
        triesForCurrentStep = 0
    }
}
