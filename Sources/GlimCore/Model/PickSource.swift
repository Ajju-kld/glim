/// Who chose a step's control. Saved with each Laya training example, so the review can mark
/// Laya's own picks and training can count them less.
public enum PickSource: String, Sendable, Equatable, Codable {
    /// Exactly one control carries the plan's label.
    case exactLabel
    /// A typing step with only one field on screen.
    case onlyField
    /// Exactly one control fits the plan's wording.
    case planMatch
    /// Laya was confident enough to pick it without the language model.
    case laya
    /// The language model picked it.
    case languageModel
}
