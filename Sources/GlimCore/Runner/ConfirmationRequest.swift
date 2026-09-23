/// What the confirmation panel shows before a step that needs the person's click.
public struct ConfirmationRequest: Sendable, Equatable {
    /// The approved step about to run.
    public let step: ScreenedStep
    /// The app it acts in.
    public let appName: String
    /// The chosen control's label, for click and typing steps.
    public let elementLabel: String?
    /// The exact text that will be typed, for typing steps.
    public let textToType: String?
    /// Every reason Glim is asking.
    public let reasons: [ConfirmationReason]
    /// For a click found by sight: the screenshot and the point, so the person sees the spot.
    public let visualClick: VisualClick?

    /// Creates a confirmation request.
    public init(
        step: ScreenedStep, appName: String, elementLabel: String?, textToType: String?,
        reasons: [ConfirmationReason], visualClick: VisualClick? = nil
    ) {
        self.step = step
        self.appName = appName
        self.elementLabel = elementLabel
        self.textToType = textToType
        self.reasons = reasons
        self.visualClick = visualClick
    }
}
