/// The safety gate's verdict on one proposed action.
public enum GateDecision: Sendable, Equatable {
    /// The action may run now.
    case allow
    /// The action waits for the person's click; the panel lists every reason.
    case needsConfirmation([ConfirmationReason])
    /// The action never runs; the task stops with the guard popup.
    case deny(GuardViolation)
}
