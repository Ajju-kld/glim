/// An allowed action ready to run: the approved step, the app to act on, and the chosen element.
public struct ExecutableAction: Sendable, Equatable {
    /// The approved step, carrying the key, direction, preset or exact text.
    public let step: StepAction
    /// The resolved app, with its process identifier or bundle location.
    public let app: ResolvedApp
    /// The element chosen for `click` or `typeText`.
    public let targetElement: UIElementSnapshot?

    /// Creates an executable action.
    public init(step: StepAction, app: ResolvedApp, targetElement: UIElementSnapshot?) {
        self.step = step
        self.app = app
        self.targetElement = targetElement
    }
}
