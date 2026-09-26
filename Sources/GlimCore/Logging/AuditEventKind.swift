/// Categories of audit events.
public enum AuditEventKind: String, Sendable, Codable {
    case transcript
    case planProposed
    case planRejected
    case planApproved
    case planCancelled
    case modelError
    case controlsOffered
    /// A click's control couldn't be read, so Glim is looking for it on a screenshot.
    case lookingBySight
    case readCheck
    case stepTiming
    case checkerVerdict
    case gateDecision
    case confirmationAnswered
    case actionPerformed
    case actionFailed
    case answerGiven
    case screenReadFailed
    case taskFinished
    case killSwitchTripped
    case killSwitchRearmed
    case settingsChanged
    /// Screen chat was turned on: the screen edge glows and questions see the whole screen.
    case screenChatStarted
    /// Screen chat was turned off, by the person or after a quiet spell.
    case screenChatEnded
    case settingsReset
}
