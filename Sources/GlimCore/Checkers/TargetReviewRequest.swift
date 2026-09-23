/// What a checker is asked to review: the approved step, the candidates on screen, and the
/// element the main model chose.
public struct TargetReviewRequest: Sendable {
    /// The person's request.
    public let goal: String
    /// The approved step being executed.
    public let step: ScreenedStep
    /// The front window's title, if any.
    public let windowTitle: String?
    /// Elements compatible with the step, from the fresh element table.
    public let candidates: [UIElementSnapshot]
    /// The main model's pick.
    public let chosenElement: UIElementSnapshot
    /// Who chose `chosenElement`, saved with Laya training examples.
    public let pickedBy: PickSource?

    /// Creates a review request.
    public init(
        goal: String,
        step: ScreenedStep,
        windowTitle: String?,
        candidates: [UIElementSnapshot],
        chosenElement: UIElementSnapshot,
        pickedBy: PickSource? = nil
    ) {
        self.goal = goal
        self.step = step
        self.windowTitle = windowTitle
        self.candidates = candidates
        self.chosenElement = chosenElement
        self.pickedBy = pickedBy
    }
}
