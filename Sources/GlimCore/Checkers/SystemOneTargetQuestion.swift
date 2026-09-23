/// The question Glim asks a System-One checker about a pick. The reviewer sends it and Laya
/// training examples store it, so training sees exactly what Laya sees.
public struct SystemOneTargetQuestion: Sendable, Equatable, Codable {
    /// The person's request.
    public let goal: String
    /// The step, without any typed text.
    public let step: String
    /// The step's action kind.
    public let action: String
    /// The app the step acts in.
    public let app: String
    /// The front window's title.
    public let windowTitle: String?
    /// The question's wording.
    public let instructions: String
    /// Each offered control by number: "label (Role)".
    public let options: [String: String]

    /// The question for `request` over `shortlist`.
    public init(request: TargetReviewRequest, shortlist: [UIElementSnapshot]) {
        let stepSummary = request.step.action.summaryWithoutTypedText
        self.init(
            goal: request.goal, step: stepSummary, action: request.step.action.kind.rawValue,
            app: request.step.app?.displayName ?? "", windowTitle: request.windowTitle,
            instructions: "Which numbered control performs this step: \(stepSummary)?",
            options: Dictionary(
                uniqueKeysWithValues: shortlist.map { element in
                    (
                        String(element.number),
                        "\(element.label) (\(ElementRoles.displayName(of: element.role)))"
                    )
                }))
    }

    init(
        goal: String, step: String, action: String, app: String, windowTitle: String?,
        instructions: String, options: [String: String]
    ) {
        self.goal = goal
        self.step = step
        self.action = action
        self.app = app
        self.windowTitle = windowTitle
        self.instructions = instructions
        self.options = options
    }

    /// The same question with every text passed through `transform`.
    func mapTexts(_ transform: (String) -> String) -> SystemOneTargetQuestion {
        SystemOneTargetQuestion(
            goal: transform(goal), step: transform(step), action: action, app: app,
            windowTitle: windowTitle.map(transform), instructions: transform(instructions),
            options: options.mapValues(transform))
    }

    var wireState: JSONValue {
        [
            "goal": .string(goal),
            "step": .string(step),
            "action": .string(action),
            "app": .string(app),
            "windowTitle": windowTitle.map { .string($0) } ?? .null,
        ]
    }

    var wireQuestion: SystemOneWireFormat.Question {
        SystemOneWireFormat.Question(
            type: SystemOneWireFormat.choiceQuestionType, instructions: instructions,
            criteria: options)
    }
}
