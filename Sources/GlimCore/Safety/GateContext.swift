/// Everything the safety gate needs to judge one proposed action.
public struct GateContext: Sendable {
    /// The step the person approved.
    public let approvedStep: ScreenedStep
    /// The concrete action code built for that step.
    public let proposedAction: ProposedAction
    /// The element table captured for this step; a chosen element must be one of these.
    public let currentElements: [UIElementSnapshot]
    /// A limit the task has hit, if any.
    public let limitViolation: LimitViolation?
    /// Second-opinion checker findings (disagreement or offline) to show the person.
    public let checkerConcerns: [ConfirmationReason]
    /// Kill switch and watchdog state.
    public let safetyState: SafetyState

    /// Creates a gate context.
    public init(
        approvedStep: ScreenedStep,
        proposedAction: ProposedAction,
        currentElements: [UIElementSnapshot],
        limitViolation: LimitViolation?,
        checkerConcerns: [ConfirmationReason],
        safetyState: SafetyState
    ) {
        self.approvedStep = approvedStep
        self.proposedAction = proposedAction
        self.currentElements = currentElements
        self.limitViolation = limitViolation
        self.checkerConcerns = checkerConcerns
        self.safetyState = safetyState
    }
}
