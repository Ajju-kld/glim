import AVFoundation
import Foundation

/// Speaks Glim's short narration with the voice and speed the person chose.
///
/// A new line interrupts the one still playing, so the voice never falls behind the actions.
@MainActor
public final class SpeechNarrator: Narrating {
    /// UserDefaults key for the chosen voice's identifier; empty means "best installed".
    public static let voiceIdentifierKey = "narrationVoiceIdentifier"
    /// UserDefaults key for the speaking speed (0.0 slowest … 1.0 fastest; 0.5 is normal).
    public static let rateKey = "narrationRate"
    /// Tunable: a little faster than normal keeps narration short.
    public static let defaultRate = 0.55
    private static let voiceLanguagePrefix = "en"
    private static let fallbackVoiceLanguage = "en-US"

    /// A voice the person can choose.
    public struct VoiceOption: Identifiable, Hashable, Sendable {
        /// The system voice identifier.
        public let id: String
        /// The name shown in the menu, with quality and language.
        public let title: String
    }

    private let synthesizer = AVSpeechSynthesizer()
    /// Whether narration is silenced (the "Mute narration" setting).
    public var isMuted: Bool

    /// Creates a narrator.
    public init(isMuted: Bool = false) {
        self.isMuted = isMuted
    }

    /// Speaks `text` unless muted, cutting off any line still playing.
    public func say(_ text: String) {
        guard !isMuted else {
            return
        }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.chosenVoice()
        utterance.rate = Self.chosenRate()
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        synthesizer.speak(utterance)
    }

    /// Stops speaking immediately.
    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Voices

    /// English voices installed on this Mac, best quality first. Premium and Enhanced voices
    /// are downloaded in System Settings → Accessibility → Spoken Content → System Voice →
    /// Manage Voices.
    public static func availableVoices() -> [VoiceOption] {
        englishVoices().map { voice in
            VoiceOption(
                id: voice.identifier,
                title: "\(voice.name) (\(qualityName(voice.quality)), \(voice.language))")
        }
    }

    private static func englishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                voice.language.hasPrefix(voiceLanguagePrefix)
                    && !voice.voiceTraits.contains(.isNoveltyVoice)
            }
            .sorted { first, second in
                if first.quality != second.quality {
                    return first.quality.rawValue > second.quality.rawValue
                }
                return first.name < second.name
            }
    }

    private static func chosenVoice() -> AVSpeechSynthesisVoice? {
        let identifier = UserDefaults.standard.string(forKey: voiceIdentifierKey) ?? ""
        if !identifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        // Nothing chosen, or the chosen voice was removed: the best installed English voice.
        return englishVoices().first ?? AVSpeechSynthesisVoice(language: fallbackVoiceLanguage)
    }

    private static func chosenRate() -> Float {
        let stored = UserDefaults.standard.object(forKey: rateKey) as? Double ?? defaultRate
        let clamped = min(max(stored, 0), 1)
        let range = AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate
        return AVSpeechUtteranceMinimumSpeechRate + Float(clamped) * range
    }

    private static func qualityName(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
        }
    }
}
