/// Why the planner could not produce a usable answer. Everything except `.model` is a model
/// error: the step is re-asked and counts as one try.
public enum PlannerError: Error, Sendable, Equatable {
    case model(LanguageModelError)
    case invalidAnswer(reason: String)
    case invalidStep(stepNumber: Int, reason: String)
    case elementNumberNotInTable(Int)

    /// A sentence for the model's retry prompt, or for the person.
    public var explanation: String {
        switch self {
        case .model(let languageModelError): languageModelError.explanation
        case .invalidAnswer(let reason): "The answer was not valid JSON for the schema: \(reason)"
        case .invalidStep(let stepNumber, let reason): "Step \(stepNumber) is invalid: \(reason)"
        case .elementNumberNotInTable(let number):
            "Element \(number) is not one of the listed controls."
        }
    }
}
