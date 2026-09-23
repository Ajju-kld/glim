/// Categories of audit events.
public enum AuditEventKind: String, Sendable, Codable {
    case transcript
    case planProposed
    case planRejected
    case planApproved
    case planCancelled
    case modelError
    case controlsOffered
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
    case settingsReset
}
