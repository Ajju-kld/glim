/// How risky an action looks, judged from the words describing its target.
public enum RiskLevel: Sendable, Equatable {
    /// No risk phrase found.
    case safe
    /// A Confirm phrase was found; the person must click Allow.
    case needsConfirmation(matchedPhrase: String)
    /// A Forbidden phrase was found; the action never runs.
    case forbidden(matchedPhrase: String)
}
