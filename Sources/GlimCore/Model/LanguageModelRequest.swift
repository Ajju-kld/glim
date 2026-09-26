import Foundation

/// One question for the language model, with the JSON shape its answer must follow.
public struct LanguageModelRequest: Sendable {
    /// Tunable: the longest answer by default — a 20-step plan fits well inside it, and a
    /// runaway generation stops instead of hanging the task.
    public static let defaultMaximumAnswerTokens = 1_024
    /// Business rule: what Glim is shown to have replied to a task in screen chat. Its real
    /// outcome isn't repeated, only that it was a request to act.
    public static let taskTurnReply = "I carried out that request on the Mac."
    /// Business rule: the words sent with the screenshot at the start of a screen chat.
    public static let screenChatScreenshotNote = "This is my screen right now."

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
    /// The screen chat so far, or nil outside screen chat. With it, the screenshots go in a
    /// message of their own first, then the earlier turns, then this question, so an unchanged
    /// screen lets Ollama reuse its cached reading of the image.
    public let earlierTurns: [ScreenChatTurn]?

    /// Creates a request.
    public init(
        systemPrompt: String, userPrompt: String, responseSchema: JSONValue,
        imagesPNG: [Data] = [], maximumAnswerTokens: Int = defaultMaximumAnswerTokens,
        earlierTurns: [ScreenChatTurn]? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.responseSchema = responseSchema
        self.imagesPNG = imagesPNG
        self.maximumAnswerTokens = maximumAnswerTokens
        self.earlierTurns = earlierTurns
    }
}
