/// What the planner proposes for one spoken request.
public struct Plan: Sendable, Hashable {
    /// The request as transcribed.
    public let goal: String
    /// Steps in execution order.
    public let steps: [StepAction]

    /// Creates a plan.
    public init(goal: String, steps: [StepAction]) {
        self.goal = goal
        self.steps = steps
    }
}
