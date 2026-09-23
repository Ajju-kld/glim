/// Live updates while the talk key is held.
public enum VoiceEvent: Sendable, Equatable {
    /// Microphone loudness, 0…1, for the waveform.
    case level(Float)
    /// Everything heard so far.
    case transcript(String)
}
