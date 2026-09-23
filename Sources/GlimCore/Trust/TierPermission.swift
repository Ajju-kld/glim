/// What a trust tier says about one kind of action.
public enum TierPermission: Sendable, Equatable {
    /// The action may never run in this tier.
    case denied
    /// The action may run once it passes the other checks.
    case allowed
    /// The action may run only after the person clicks Allow.
    case allowedWithConfirmation
}
