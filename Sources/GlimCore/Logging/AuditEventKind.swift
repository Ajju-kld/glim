/// Categories of audit events.
public enum AuditEventKind: String, Sendable, Codable {
    case settingsChanged
    case settingsReset
}
