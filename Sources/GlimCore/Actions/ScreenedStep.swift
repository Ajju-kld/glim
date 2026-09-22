/// A plan step after screening: the action plus the verified app it targets and that app's tier.
public struct ScreenedStep: Sendable, Hashable {
    /// Position in the plan, starting at 1.
    public let number: Int
    /// The approved action.
    public let action: StepAction
    /// The verified app the step acts on; nil only for `speak`, which touches no app.
    public let app: AppIdentity?
    /// The app's trust tier at screening time; nil only for `speak`.
    public let tier: TrustTier?

    /// Creates a screened step.
    public init(number: Int, action: StepAction, app: AppIdentity?, tier: TrustTier?) {
        self.number = number
        self.action = action
        self.app = app
        self.tier = tier
    }
}
