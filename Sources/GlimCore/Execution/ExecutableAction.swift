/// An allowed action ready to run: the approved step, the app to act on, and the chosen element.
public struct ExecutableAction: Sendable, Equatable {
    /// The approved step, carrying the key, direction, preset or exact text.
    public let step: StepAction
    /// The resolved app, with its process identifier or bundle location.
    public let app: ResolvedApp
    /// The element chosen for `click` or `typeText`.
    public let targetElement: UIElementSnapshot?
    /// The point found by sight, for a `click` whose control could not be read.
    public let visualTarget: VisualTarget?

    /// Creates an executable action.
    public init(
        step: StepAction, app: ResolvedApp, targetElement: UIElementSnapshot?,
        visualTarget: VisualTarget? = nil
    ) {
        self.step = step
        self.app = app
        self.targetElement = targetElement
        self.visualTarget = visualTarget
    }
}
