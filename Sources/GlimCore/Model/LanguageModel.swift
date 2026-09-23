/// Something that answers a ``LanguageModelRequest`` with JSON text matching its schema.
public protocol LanguageModel: Sendable {
    /// Returns the model's answer as JSON text.
    func respond(to request: LanguageModelRequest) async throws(LanguageModelError) -> String
}
