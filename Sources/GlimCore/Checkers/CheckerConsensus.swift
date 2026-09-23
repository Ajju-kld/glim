/// Runs every enabled checker at once and turns their verdicts into confirmation reasons.
///
/// Only a confident disagreement or an offline checker becomes a reason to ask the person;
/// agreement and abstention are logged but don't interrupt.
public struct CheckerConsensus: Sendable {
    private let checkers: [any TargetChecker]

    /// Creates a consensus over `checkers`, reported in this order.
    public init(checkers: [any TargetChecker]) {
        self.checkers = checkers
    }

    /// Reviews the pick with every checker concurrently.
    public func review(_ request: TargetReviewRequest) async -> CheckerConsensusResult {
        let outcomes = await withTaskGroup(of: (Int, CheckerOutcome).self) { group in
            for (index, checker) in checkers.enumerated() {
                group.addTask {
                    let verdict = await checker.review(request)
                    return (index, CheckerOutcome(checkerName: checker.name, verdict: verdict))
                }
            }
            var indexedOutcomes: [(Int, CheckerOutcome)] = []
            for await indexedOutcome in group {
                indexedOutcomes.append(indexedOutcome)
            }
            return indexedOutcomes.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return CheckerConsensusResult(outcomes: outcomes)
    }
}
