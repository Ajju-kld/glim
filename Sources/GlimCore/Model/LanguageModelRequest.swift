import Foundation

/// One question for the language model, with the JSON shape its answer must follow.
public struct LanguageModelRequest: Sendable {
    /// Role and rules for the model.
    public let systemPrompt: String
    /// The question, with context.
    public let userPrompt: String
    /// JSON schema the answer must match; the model is constrained to it.
    public let responseSchema: JSONValue
    /// Screenshots as PNG data, for the vision fallback. Kept in memory only.
    public let imagesPNG: [Data]

    /// Creates a request.
    public init(
        systemPrompt: String, userPrompt: String, responseSchema: JSONValue, imagesPNG: [Data] = []
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.responseSchema = responseSchema
        self.imagesPNG = imagesPNG
    }
}
