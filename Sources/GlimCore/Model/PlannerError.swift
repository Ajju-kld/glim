/// Why the planner could not produce a usable answer. Everything except `.model` is a model
/// error: the step is re-asked and counts as one try.
public enum PlannerError: Error, Sendable, Equatable {
    case model(LanguageModelError)
    case invalidAnswer(reason: String)
    case invalidStep(stepNumber: Int, reason: String)
    case elementNumberNotInTable(Int)
}
