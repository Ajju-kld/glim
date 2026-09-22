/// Why listening could not start or finish.
public enum VoiceInputError: Error, Sendable, Equatable {
    case microphoneNotAllowed
    case speechRecognitionNotAllowed
    case localeNotSupported
    case speechUnavailable(reason: String)
    case audioEngineFailed(reason: String)
    case notListening

    /// One sentence for the popup, naming the fix when there is one.
    public var explanation: String {
        switch self {
        case .microphoneNotAllowed:
            "Glim needs microphone access (System Settings → Privacy & Security → Microphone)."
        case .speechRecognitionNotAllowed:
            "Glim needs Speech Recognition access (System Settings → Privacy & Security)."
        case .localeNotSupported:
            "On-device English speech recognition isn't available on this Mac."
        case .speechUnavailable(let reason):
            "Speech recognition isn't ready: \(reason)"
        case .audioEngineFailed(let reason):
            "The microphone could not start: \(reason)"
        case .notListening:
            "Glim wasn't listening."
        }
    }
}
