/// Phrases that make an action forbidden or make it wait for the person's click.
///
/// Matching rules live in ``RiskClassifier``.
public struct RiskWordLists: Sendable, Equatable, Codable {
    /// Business rule: phrases that always block an action.
    public var forbidden: [String]
    /// Business rule: phrases that make an action wait for the person's click.
    public var confirm: [String]

    /// Creates word lists.
    public init(forbidden: [String], confirm: [String]) {
        self.forbidden = forbidden
        self.confirm = confirm
    }
}
