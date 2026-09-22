import Foundation

/// Shared review logic for System-One checkers: shortlist, ask one `choice` question, and apply
/// the confident-disagreement rule.
struct SystemOneTargetReviewer: Sendable {
    private enum ReviewFailure: Error {
        case transport(String)
        case badStatus(Int, String)
        case unreadableAnswer(String)
        case missingAnswer

        var explanation: String {
            switch self {
            case .transport(let reason): "Could not reach the checker: \(reason)"
            case .badStatus(let statusCode, let body):
                "The checker answered HTTP \(statusCode): \(body)"
            case .unreadableAnswer(let reason): "The checker's answer could not be read: \(reason)"
            case .missingAnswer: "The checker returned no answer."
            }
        }
    }

    private static let successStatusCodes = 200..<300

    let endpoint: NetworkEndpoint
    let modelName: String?
    let transport: any HTTPTransport
    let confidenceThreshold: Double

    func review(_ request: TargetReviewRequest, bearerToken: String?) async -> CheckerVerdict {
        let shortlist = CandidateShortlist.shortlist(
            request.candidates,
            targetDescription: request.step.action.targetDescription ?? "",
            limit: CheckerTuning.shortlistLimit)
        guard shortlist.contains(request.chosenElement) else {
            return .abstains(reason: "The pick is outside the checker's shortlist.")
        }
        let answer: SystemOneWireFormat.Answer
        do {
            answer = try await ask(about: request, shortlist: shortlist, bearerToken: bearerToken)
        } catch let failure as ReviewFailure {
            return .unavailable(reason: failure.explanation)
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
        return verdict(for: answer, shortlist: shortlist, chosenElement: request.chosenElement)
    }

    private func verdict(
        for answer: SystemOneWireFormat.Answer,
        shortlist: [UIElementSnapshot],
        chosenElement: UIElementSnapshot
    ) -> CheckerVerdict {
        guard let choice = answer.choice,
            let pickedElement = shortlist.first(where: { String($0.number) == choice })
        else {
            return .abstains(reason: "The checker picked an option that was not offered.")
        }
        if pickedElement == chosenElement {
            return .agrees
        }
        let probability = answer.probabilities?[choice] ?? answer.confidence ?? 0
        guard probability >= confidenceThreshold else {
            return .abstains(reason: "The checker was unsure (\(probability)).")
        }
        return .confidentlyDisagrees(alternative: pickedElement, probability: probability)
    }

    private func ask(
        about request: TargetReviewRequest, shortlist: [UIElementSnapshot], bearerToken: String?
    ) async throws -> SystemOneWireFormat.Answer {
        let criteria = Dictionary(
            uniqueKeysWithValues: shortlist.map { element in
                (
                    String(element.number),
                    "\(element.label) (\(ElementRoles.displayName(of: element.role)))"
                )
            })
        let wireRequest = SystemOneWireFormat.Request(
            state: [
                "goal": .string(request.goal),
                "step": .string(request.step.action.summary),
                "action": .string(request.step.action.kind.rawValue),
                "app": .string(request.step.app?.displayName ?? ""),
                "windowTitle": request.windowTitle.map { .string($0) } ?? .null,
            ],
            model: modelName,
            questions: [
                SystemOneWireFormat.targetQuestionIdentifier: SystemOneWireFormat.Question(
                    type: SystemOneWireFormat.choiceQuestionType,
                    instructions:
                        "Which numbered control performs this step: \(request.step.action.summary)?",
                    criteria: criteria)
            ])

        var urlRequest = URLRequest(
            url: try endpoint.url(path: "/v1/systemone"),
            timeoutInterval: CheckerTuning.requestTimeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken {
            urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONEncoder().encode(wireRequest)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(urlRequest)
        } catch {
            throw ReviewFailure.transport(error.localizedDescription)
        }
        guard Self.successStatusCodes.contains(response.statusCode) else {
            throw ReviewFailure.badStatus(
                response.statusCode, String(decoding: data, as: UTF8.self))
        }
        let decodedResponse: SystemOneWireFormat.Response
        do {
            decodedResponse = try JSONDecoder().decode(
                SystemOneWireFormat.Response.self, from: data)
        } catch {
            throw ReviewFailure.unreadableAnswer(error.localizedDescription)
        }
        guard let answer = decodedResponse.answers[SystemOneWireFormat.targetQuestionIdentifier]
        else {
            throw ReviewFailure.missingAnswer
        }
        return answer
    }
}
