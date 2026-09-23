/// One checker's verdict, labelled with the checker's name for panels and the audit log.
public struct CheckerOutcome: Sendable, Equatable {
    /// The checker's name.
    public let checkerName: String
    /// What it concluded.
    public let verdict: CheckerVerdict

    /// Creates an outcome.
    public init(checkerName: String, verdict: CheckerVerdict) {
        self.checkerName = checkerName
        self.verdict = verdict
    }
}
