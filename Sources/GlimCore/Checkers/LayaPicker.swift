import Foundation

/// Uses the local Laya service to pick a step's control directly, without a language model.
///
/// Laya only chooses among offered options, so it can pick targets but cannot write plans.
/// A pick is used only when Laya is confident; otherwise the planner falls back to the
/// language model. Every pick still goes through the plan match and the safety gate.
public struct LayaPicker: Sendable {
    /// Tunable: how sure Laya must be before its pick replaces a model call.
    public static let defaultConfidenceThreshold = 0.80
    /// Tunable: Laya answers in well under a second when running; fail fast when it isn't.
    public static let requestTimeoutSeconds: TimeInterval = 3
    /// Tunable: Laya's first answer after starting loads its model (measured 3.4 s on an M2), so
    /// the warm-up question may take this long.
    public static let warmUpTimeoutSeconds: TimeInterval = 30
    private static let warmUpStep = StepAction.click(appName: "Glim", target: "OK")
    private static let warmUpOptions = [
        UIElementSnapshot(number: 1, role: "AXButton", label: "OK"),
        UIElementSnapshot(number: 2, role: "AXButton", label: "Cancel"),
    ]
    private static let successStatusCodes = 200..<300

    private let transport: any HTTPTransport
    private let confidenceThreshold: Double

    /// Creates a picker that asks Laya over `transport` and trusts picks at or above
    /// `confidenceThreshold`.
    public init(
        transport: any HTTPTransport,
        confidenceThreshold: Double = LayaPicker.defaultConfidenceThreshold
    ) {
        self.transport = transport
        self.confidenceThreshold = confidenceThreshold
    }

    /// Asks Laya one throwaway question so it loads its model now, not on the first real pick.
    /// The answer is ignored; Laya being down is fine, since picking falls back to the model.
    public func warmUp() async {
        _ = await answer(
            for: Self.warmUpStep, goal: "warm up", appName: "Glim", windowTitle: nil,
            among: Self.warmUpOptions, timeoutSeconds: Self.warmUpTimeoutSeconds)
    }

    /// Laya's confident pick among `candidates`, or `nil` when it is unsure or unavailable.
    ///
    /// `appName` and `windowTitle` are sent exactly as the checker sends them, so Laya is asked
    /// on the same inputs its training examples record.
    public func pick(
        for step: StepAction, goal: String, appName: String, windowTitle: String?,
        among candidates: [UIElementSnapshot]
    ) async -> UIElementSnapshot? {
        guard candidates.count > 1,
            let (element, probability) = await answer(
                for: step, goal: goal, appName: appName, windowTitle: windowTitle,
                among: candidates, timeoutSeconds: Self.requestTimeoutSeconds)
        else {
            return nil
        }
        return probability >= confidenceThreshold ? element : nil
    }

    /// Laya's choice among `candidates` with its probability, or `nil` when it didn't answer
    /// with one of them.
    private func answer(
        for step: StepAction, goal: String, appName: String, windowTitle: String?,
        among candidates: [UIElementSnapshot], timeoutSeconds: TimeInterval
    ) async -> (UIElementSnapshot, Double)? {
        let summary = step.summaryWithoutTypedText
        let question = SystemOneTargetQuestion(
            goal: goal, step: summary, action: step.kind.rawValue, app: appName,
            windowTitle: windowTitle,
            instructions: "Which numbered control performs this step: \(summary)?",
            options: Dictionary(
                uniqueKeysWithValues: candidates.map { element in
                    (
                        String(element.number),
                        "\(element.label) (\(ElementRoles.displayName(of: element.role)))"
                    )
                }))
        let wireRequest = SystemOneWireFormat.Request(
            state: question.wireState, model: nil,
            questions: [SystemOneWireFormat.targetQuestionIdentifier: question.wireQuestion])

        do {
            var urlRequest = URLRequest(
                url: try NetworkEndpoint.layaService.url(path: "/v1/systemone"),
                timeoutInterval: timeoutSeconds)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONEncoder().encode(wireRequest)
            let (data, response) = try await transport.send(urlRequest)
            guard Self.successStatusCodes.contains(response.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(SystemOneWireFormat.Response.self, from: data)
            guard let answer = decoded.answers[SystemOneWireFormat.targetQuestionIdentifier],
                let choice = answer.choice,
                let element = candidates.first(where: { String($0.number) == choice })
            else {
                return nil
            }
            return (element, answer.probabilities?[choice] ?? answer.confidence ?? 0)
        } catch {
            // Laya not running, slow or unreadable: the language model picks instead.
            return nil
        }
    }
}
