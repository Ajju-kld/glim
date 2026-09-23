import Foundation

/// One question for the language model, with the JSON shape its answer must follow.
public struct LanguageModelRequest: Sendable {
    /// Tunable: the longest answer by default — a 20-step plan fits well inside it, and a
    /// runaway generation stops instead of hanging the task.
    public static let defaultMaximumAnswerTokens = 1_024

    /// Role and rules for the model.
    public let systemPrompt: String
    /// The question, with context.
    public let userPrompt: String
    /// JSON schema the answer must match; the model is constrained to it.
    public let responseSchema: JSONValue
    /// Screenshots as PNG data, for the vision fallback. Kept in memory only.
    public let imagesPNG: [Data]
    /// The most tokens the answer may use. Each one costs time, so short answers get a low cap.
    public let maximumAnswerTokens: Int

    /// Creates a request.
    public init(
        systemPrompt: String, userPrompt: String, responseSchema: JSONValue,
        imagesPNG: [Data] = [], maximumAnswerTokens: Int = defaultMaximumAnswerTokens
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.responseSchema = responseSchema
        self.imagesPNG = imagesPNG
        self.maximumAnswerTokens = maximumAnswerTokens
    }
}
