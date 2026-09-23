import Foundation

/// One line in the audit log.
public struct AuditEvent: Sendable, Equatable, Codable {
    /// When the event happened.
    public let timestamp: Date
    /// What kind of event it is.
    public let kind: AuditEventKind
    /// One human-readable sentence.
    public let summary: String
    /// Extra facts, such as the loosenings a settings change made.
    public let details: [String: String]

    /// Creates an event.
    public init(timestamp: Date, kind: AuditEventKind, summary: String, details: [String: String]) {
        self.timestamp = timestamp
        self.kind = kind
        self.summary = summary
        self.details = details
    }
}
