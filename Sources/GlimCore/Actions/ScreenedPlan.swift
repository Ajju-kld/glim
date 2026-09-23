/// A plan that passed screening and is ready to show the person for approval.
public struct ScreenedPlan: Sendable, Hashable {
    /// The request as transcribed.
    public let goal: String
    /// Screened steps in execution order.
    public let steps: [ScreenedStep]

    /// Creates a screened plan.
    public init(goal: String, steps: [ScreenedStep]) {
        self.goal = goal
        self.steps = steps
    }
}
