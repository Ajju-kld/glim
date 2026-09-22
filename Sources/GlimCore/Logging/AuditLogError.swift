/// Why the audit log could not be written or read.
public enum AuditLogError: Error, Sendable, Equatable {
    case cannotCreateDirectory(path: String, reason: String)
    case cannotWrite(path: String, reason: String)
    case cannotRead(path: String, reason: String)
    case cannotDelete(path: String, reason: String)
    case cannotEncode(reason: String)
}
