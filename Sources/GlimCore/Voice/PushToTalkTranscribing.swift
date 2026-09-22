/// Turns speech into text while the talk key is held.
public protocol PushToTalkTranscribing: Sendable {
    /// Starts the microphone and on-device recognition; events stream until listening stops.
    func startListening() async throws(VoiceInputError) -> AsyncStream<VoiceEvent>
    /// Stops the microphone and returns the final transcript.
    func stopListening() async throws(VoiceInputError) -> String
    /// Stops immediately and discards what was heard (kill switch).
    func cancelListening() async
}
