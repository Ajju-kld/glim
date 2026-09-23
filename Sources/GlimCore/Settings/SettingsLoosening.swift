/// One way a settings change makes Glim less safe or less private. Any loosening needs the
/// owner's Touch ID or password.
public enum SettingsLoosening: Sendable, Equatable {
    case removedForbiddenPhrase(String)
    case removedConfirmPhrase(String)
    case appMovedToLessRestrictiveTier(bundleIdentifier: String, from: TrustTier, to: TrustTier)
    case defaultTierLoosened(from: TrustTier, to: TrustTier)
    case limitLoosened(SafetyLimitName)
    case jevEnabled
    case jevExclusionRemoved(bundleIdentifier: String)
    case plannerModelChanged(from: String, to: String)
    case lowRiskPlansStartWithoutApproval

    /// One phrase for the Touch ID prompt and the audit log.
    public var explanation: String {
        switch self {
        case .removedForbiddenPhrase(let phrase):
            "stop forbidding “\(phrase)”"
        case .removedConfirmPhrase(let phrase):
            "stop asking before “\(phrase)”"
        case .appMovedToLessRestrictiveTier(let bundleIdentifier, let previousTier, let newTier):
            "move \(bundleIdentifier) from \(previousTier.displayName) to \(newTier.displayName)"
        case .defaultTierLoosened(let previousTier, let newTier):
            "change the default tier from \(previousTier.displayName) to \(newTier.displayName)"
        case .limitLoosened(let limitName):
            "loosen the limit “\(limitName.displayName)”"
        case .jevEnabled:
            "turn on Jev, which sends goals and button labels to TypeSafe’s servers"
        case .jevExclusionRemoved(let bundleIdentifier):
            "let Jev see \(bundleIdentifier)"
        case .plannerModelChanged(let previousModel, let newModel):
            "switch the AI model from \(previousModel) to \(newModel)"
        case .lowRiskPlansStartWithoutApproval:
            "start low-risk plans without asking you first"
        }
    }
}
