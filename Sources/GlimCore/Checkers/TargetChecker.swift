/// A second opinion on which element performs a step.
public protocol TargetChecker: Sendable {
    /// Shown in confirmation panels, such as "Laya".
    var name: String { get }
    /// Reviews the main model's pick. Never throws: failures are `.unavailable`.
    func review(_ request: TargetReviewRequest) async -> CheckerVerdict
}
