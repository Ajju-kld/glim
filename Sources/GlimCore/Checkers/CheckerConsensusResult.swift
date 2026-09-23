/// Every checker's verdict for one pick, plus the concerns to show the person.
public struct CheckerConsensusResult: Sendable, Equatable {
    /// Verdicts in checker order.
    public let outcomes: [CheckerOutcome]

    /// Creates a result.
    public init(outcomes: [CheckerOutcome]) {
        self.outcomes = outcomes
    }

    /// Confident disagreements and offline checkers, for the safety gate.
    public var concerns: [ConfirmationReason] {
        outcomes.compactMap { outcome in
            switch outcome.verdict {
            case .confidentlyDisagrees(let alternative, _):
                .checkerDisagrees(
                    checkerName: outcome.checkerName, checkerChoice: alternative.label)
            case .unavailable:
                .checkerOffline(checkerName: outcome.checkerName)
            case .agrees, .abstains:
                nil
            }
        }
    }
}
