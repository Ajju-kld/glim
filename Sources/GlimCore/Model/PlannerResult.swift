/// What a spoken request turned out to be.
public enum PlannerResult: Sendable, Equatable {
    /// A question about the screen; answered by reading, never by acting.
    case question
    /// A task with a plan to screen and approve.
    case task(Plan)
}
