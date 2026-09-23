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
    /// Tunable: controls the model sees on a first pick. Reading the prompt is most of a
    /// pick's time on a laptop, so it gets the closest matches first and every control on retry.
    public static let pickShortlistLimit = 20
    /// Tunable: a pick answer is a number and a flag; this cap stops a runaway answer early.
    public static let pickAnswerTokenLimit = 64
    /// Tunable: front-window controls listed in the planning prompt, those closest to the
    /// request. A whole window's list slowed planning and tempted the model to copy it.
    public static let planningControlLimit = 20

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
                responseSchema: PlannerSchemas.plan(limits: context.limits)))
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

    /// Finds the element that performs `step`, offering only elements the step can target.
    ///
    /// When exactly one of them is labelled with the step's target (ignoring case, accents,
    /// width and surrounding spaces), it is chosen without asking the model: the approved plan
    /// named it, and a model call would only add time. A typing step with only one field on
    /// screen types there, since there is nowhere else to type. Otherwise the model picks.
    ///
    /// - Parameters:
    ///   - step: The approved step.
    ///   - goal: The person's request.
    ///   - table: The fresh element table.
    ///   - retryNote: Why the previous answer was rejected; the model runs at temperature 0,
    ///     so a retry without feedback would repeat the same answer.
    /// - Returns: The chosen compatible element, or the model's report that none fits.
    /// - Throws: ``PlannerError`` when the model fails or answers with an unusable pick.
    public func pickTarget(
        for step: StepAction, goal: String, among table: [UIElementSnapshot],
        retryNote: String? = nil
    ) async throws(PlannerError) -> TargetChoice {
        let candidates = ElementRoles.candidates(in: table, for: step.kind)
        if let exactMatch = Self.onlyElementLabelled(step.targetDescription, in: candidates) {
            return .element(exactMatch)
        }
        if step.kind == .typeText, candidates.count == 1, let onlyField = candidates.first {
            return .element(onlyField)
        }
        if let onlyMatch = Self.onlyElementMatchingPlan(step.targetDescription, in: candidates) {
            return .element(onlyMatch)
        }
        let offeredCandidates =
            retryNote == nil
            ? CandidateShortlist.shortlist(
                candidates, targetDescription: step.targetDescription ?? "",
                limit: Self.pickShortlistLimit)
            : candidates
        var prompt = Self.targetPrompt(for: step, goal: goal, candidates: offeredCandidates)
        if let retryNote {
            prompt += "\nYour previous answer was rejected: \(retryNote)"
        }
        let answerText = try await ask(
            LanguageModelRequest(
                systemPrompt: PlannerPrompts.targetPicking,
                userPrompt: prompt,
                responseSchema: PlannerSchemas.target,
                maximumAnswerTokens: Self.pickAnswerTokenLimit))
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

    private static func onlyElementLabelled(
        _ targetDescription: String?, in candidates: [UIElementSnapshot]
    ) -> UIElementSnapshot? {
        guard let targetDescription else {
            return nil
        }
        let wantedLabel = targetDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = candidates.filter { element in
            element.label.trimmingCharacters(in: .whitespacesAndNewlines).compare(
                wantedLabel, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
            ) == .orderedSame
        }
        return matches.count == 1 ? matches.first : nil
    }

    /// The one control the plan's wording fits, by the same rule that accepts a model's pick.
    private static func onlyElementMatchingPlan(
        _ targetDescription: String?, in candidates: [UIElementSnapshot]
    ) -> UIElementSnapshot? {
        guard let targetDescription else {
            return nil
        }
        let matcher = PlanMatcher()
        let matches = candidates.filter { element in
            matcher.elementMatchesPlan(targetDescription: targetDescription, element: element)
        }
        return matches.count == 1 ? matches.first : nil
    }

    // MARK: - Prompts

    /// The lists that rarely change come first and the request comes last, so Ollama can reuse
    /// its cached reading of the prompt's start instead of reading every line again.
    static func planningPrompt(for context: PlanningContext) -> String {
        let relevantLabels = CandidateShortlist.relevantLabels(
            context.elementLabels, to: context.goal, limit: planningControlLimit)
        let controlLines = relevantLabels.map { "- \($0)" }.joined(separator: "\n")
        return """
            Installed apps: \(context.installedAppNames.joined(separator: ", "))
            Running apps: \(context.runningAppNames.joined(separator: ", "))
            Front app: \(context.frontAppName ?? "none")
            Window title: \(context.windowTitle ?? "none")
            Controls in the front window:
            \(controlLines.isEmpty ? "(none)" : controlLines)
            Request: \(context.goal)
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
