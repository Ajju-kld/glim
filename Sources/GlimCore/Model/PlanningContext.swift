/// What the planner may see: labels only, never screen content (B-Q8), so text inside
/// documents, emails or web pages can't smuggle steps into a plan.
public struct PlanningContext: Sendable, Equatable {
    /// The request as transcribed.
    public let goal: String
    /// The frontmost app's name.
    public let frontAppName: String?
    /// The front window's title.
    public let windowTitle: String?
    /// Labels of the actionable controls in the front window.
    public let elementLabels: [String]
    /// Names of installed apps the plan may open.
    public let installedAppNames: [String]
    /// Names of running apps the plan may switch to, arrange or quit.
    public let runningAppNames: [String]
    /// The limits in effect, which bound the plan the model may write.
    public let limits: SafetyLimits
    /// In screen chat, the person's own earlier requests, oldest first, so a follow-up such as
    /// "open the second one" can be planned. Never Glim's answers, which come from the screen.
    public let earlierRequests: [String]

    /// Creates a planning context.
    public init(
        goal: String,
        frontAppName: String?,
        windowTitle: String?,
        elementLabels: [String],
        installedAppNames: [String],
        runningAppNames: [String],
        limits: SafetyLimits = .safeDefaults,
        earlierRequests: [String] = []
    ) {
        self.goal = goal
        self.frontAppName = frontAppName
        self.windowTitle = windowTitle
        self.elementLabels = elementLabels
        self.installedAppNames = installedAppNames
        self.runningAppNames = runningAppNames
        self.limits = limits
        self.earlierRequests = earlierRequests
    }
}
