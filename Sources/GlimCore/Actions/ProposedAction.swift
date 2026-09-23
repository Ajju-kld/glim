/// A concrete action about to run, built by code from an approved step and a fresh screen.
public struct ProposedAction: Sendable, Equatable {
    /// What the action does.
    public let kind: ActionKind
    /// The app the action affects: the named app, or the front app for in-app actions.
    public let targetApp: AppIdentity
    /// The chosen control, for `click` and `typeText`.
    public let targetElement: UIElementSnapshot?
    /// The text to type, for `typeText`.
    public let text: String?
    /// The key to press, for `pressKey`.
    public let key: AllowedKey?

    /// Creates a proposed action. Only the parameters that apply to `kind` are set.
    public init(
        kind: ActionKind,
        targetApp: AppIdentity,
        targetElement: UIElementSnapshot? = nil,
        text: String? = nil,
        key: AllowedKey? = nil
    ) {
        self.kind = kind
        self.targetApp = targetApp
        self.targetElement = targetElement
        self.text = text
        self.key = key
    }
}
