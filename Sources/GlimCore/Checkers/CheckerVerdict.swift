/// One checker's opinion of the main model's pick.
public enum CheckerVerdict: Sendable, Equatable {
    /// The checker picked the same element.
    case agrees
    /// The checker is confident a different element is right.
    case confidentlyDisagrees(alternative: UIElementSnapshot, probability: Double)
    /// The checker declined to judge (unsure, excluded app, pick outside its shortlist).
    case abstains(reason: String)
    /// The checker could not be reached or answered with an error.
    case unavailable(reason: String)
}
