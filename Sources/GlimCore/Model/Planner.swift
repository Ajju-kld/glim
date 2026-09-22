import Foundation

/// Asks the language model for plans, target picks and answers, and turns its JSON into typed
/// values. The model never acts; everything it returns is screened by code afterwards.
public struct Planner: Sendable {
    private struct TargetAnswer: Decodable {
        let elementNumber: Int
        let blocked: Bool
        let reason: String?
    }

    private struct QuestionAnswer: Decodable {
        let answer: String
    }

    private static let defaultBlockedReason = "The AI could not find a matching control."

    private let languageModel: any LanguageModel

    /// Creates a planner backed by `languageModel`.
    public init(languageModel: any LanguageModel) {
        self.languageModel = languageModel
    }

    /// Turns a request into a plan, or recognizes it as a question.
    public func makePlan(for context: PlanningContext) async throws(PlannerError) -> PlannerResult {
        let answerText = try await ask(
            LanguageModelRequest(
                systemPrompt: PlannerPrompts.planning,
                userPrompt: Self.planningPrompt(for: context),
                responseSchema: PlannerSchemas.plan))
        let answer = try decode(PlanAnswer.self, from: answerText)
        switch answer.kind {
        case "question":
            return .question
        case "task":
            var steps: [StepAction] = []
            for (offset, step) in answer.steps.enumerated() {
                steps.append(try step.stepAction(number: offset + 1))
            }
            return .task(Plan(goal: context.goal, steps: steps))
        default:
            throw .invalidAnswer(reason: "Unknown kind “\(answer.kind)”.")
        }
    }

    /// Asks which element performs `step`, offering only elements the step can target.
    public func pickTarget(
        for step: StepAction, goal: String, among table: [UIElementSnapshot]
    ) async throws(PlannerError) -> TargetChoice {
        let candidates = ElementRoles.candidates(in: table, for: step.kind)
        let answerText = try await ask(
            LanguageModelRequest(
                systemPrompt: PlannerPrompts.targetPicking,
                userPrompt: Self.targetPrompt(for: step, goal: goal, candidates: candidates),
                responseSchema: PlannerSchemas.target))
        let answer = try decode(TargetAnswer.self, from: answerText)
        if answer.blocked {
            return .blocked(reason: answer.reason ?? Self.defaultBlockedReason)
        }
        guard let element = candidates.first(where: { $0.number == answer.elementNumber }) else {
            throw .elementNumberNotInTable(answer.elementNumber)
        }
        return .element(element)
    }

    /// Answers a question about the screen from its text, or from a screenshot when the text
    /// is too thin.
    public func answerQuestion(
        _ question: String, screenText: String?, screenshotPNG: Data?
    ) async throws(PlannerError) -> String {
        var prompt = "Question: \(question)"
        if let screenText {
            prompt += "\nScreen text:\n\(screenText)"
        }
        let answerText = try await ask(
            LanguageModelRequest(
                systemPrompt: PlannerPrompts.questionAnswering,
                userPrompt: prompt,
                responseSchema: PlannerSchemas.answer,
                imagesPNG: screenshotPNG.map { [$0] } ?? []))
        return try decode(QuestionAnswer.self, from: answerText).answer
    }

    // MARK: - Prompts

    static func planningPrompt(for context: PlanningContext) -> String {
        let controlLines = context.elementLabels.map { "- \($0)" }.joined(separator: "\n")
        return """
            Request: \(context.goal)
            Front app: \(context.frontAppName ?? "none")
            Window title: \(context.windowTitle ?? "none")
            Controls in the front window:
            \(controlLines.isEmpty ? "(none)" : controlLines)
            Installed apps: \(context.installedAppNames.joined(separator: ", "))
            Running apps: \(context.runningAppNames.joined(separator: ", "))
            """
    }

    static func targetPrompt(
        for step: StepAction, goal: String, candidates: [UIElementSnapshot]
    ) -> String {
        let controlLines = candidates.map { element in
            "[\(element.number)] \(element.label) (\(ElementRoles.displayName(of: element.role)))"
        }
        return """
            Goal: \(goal)
            Step: \(step.summary)
            Controls:
            \(controlLines.isEmpty ? "(none)" : controlLines.joined(separator: "\n"))
            """
    }

    // MARK: - Model

    private func ask(_ request: LanguageModelRequest) async throws(PlannerError) -> String {
        do {
            return try await languageModel.respond(to: request)
        } catch {
            throw .model(error)
        }
    }

    private func decode<Decoded: Decodable>(
        _ type: Decoded.Type, from answerText: String
    ) throws(PlannerError) -> Decoded {
        do {
            return try JSONDecoder().decode(type, from: Data(answerText.utf8))
        } catch {
            throw .invalidAnswer(reason: error.localizedDescription)
        }
    }
}
