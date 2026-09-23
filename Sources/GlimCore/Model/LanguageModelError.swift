/// Why the language model could not answer.
public enum LanguageModelError: Error, Sendable, Equatable {
    /// Ollama isn't running; the fix is `brew services start ollama`.
    case serverUnreachable(reason: String)
    /// The model isn't pulled; the fix is `ollama pull <model>`.
    case modelNotInstalled(modelName: String)
    case timedOut
    /// The request was cancelled, for example because the person pressed STOP.
    case cancelled
    case badResponse(statusCode: Int, message: String)
    case malformedResponse(reason: String)
    case blockedByNetworkPolicy(NetworkPolicyError)
    /// The configured model is a cloud model; Glim only uses models that run on this Mac.
    case modelNotAllowed(modelName: String)

    /// One sentence for the popup, including the command that fixes it when there is one.
    public var explanation: String {
        switch self {
        case .serverUnreachable:
            "Ollama isn't running. Start it with: brew services start ollama"
        case .modelNotInstalled(let modelName):
            "The model \(modelName) isn't installed. Install it with: ollama pull \(modelName)"
        case .timedOut:
            "The model took too long to answer."
        case .cancelled:
            "The request to the model was cancelled."
        case .badResponse(let statusCode, let message):
            "Ollama answered with an error (\(statusCode)): \(message)"
        case .malformedResponse(let reason):
            "The model's answer could not be read: \(reason)"
        case .blockedByNetworkPolicy:
            "The request was blocked by Glim's network allowlist."
        case .modelNotAllowed(let modelName):
            "\(modelName) is not a local model. Glim only uses models that run on this Mac."
        }
    }
}
