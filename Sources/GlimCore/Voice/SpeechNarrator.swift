import AVFoundation

/// The live narrator, using the built-in on-device voice.
@MainActor
public final class SpeechNarrator: Narrating {
    private static let voiceLanguage = "en-US"

    private let synthesizer = AVSpeechSynthesizer()
    /// Whether narration is silenced (the "Mute narration" setting).
    public var isMuted: Bool

    /// Creates a narrator.
    public init(isMuted: Bool = false) {
        self.isMuted = isMuted
    }

    /// Speaks `text` unless muted.
    public func say(_ text: String) {
        guard !isMuted else {
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLanguage)
        synthesizer.speak(utterance)
    }

    /// Stops speaking immediately.
    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
