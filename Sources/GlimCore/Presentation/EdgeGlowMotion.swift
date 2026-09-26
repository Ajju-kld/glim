/// How the screen glow moves. Its window turns and pulses the glow with Core Animation, so
/// these are the only numbers the app sends; nothing is computed per frame.
public enum EdgeGlowMotion {
    /// Tunable: brightness while screen chat waits for the person to speak.
    public static let restingBrightness = 0.55
    /// Tunable: extra brightness at the loudest voice.
    static let loudestVoiceBoost = 0.45
    /// Tunable: voice levels are rounded to steps this size, so the glow changes a few times a
    /// second at most instead of on every microphone update.
    static let voiceLevelStep = 0.1
    /// Tunable: how much brighter the glow gets at the top of a pulse while Glim thinks or acts.
    public static let pulseDepth = 0.3
    /// Tunable: one pulse while Glim thinks or acts.
    public static let pulseSeconds = 1.4
    /// Tunable: how long the colours take to turn once around the screen.
    public static let secondsPerTurn = 18.0

    /// The glow's steady brightness, 0…1, for `mood`; nil means screen chat is waiting.
    static func brightness(for mood: OrbMood?) -> Double {
        switch mood {
        case .none, .waiting, .done, .thinking, .acting:
            return restingBrightness
        case .listening(let level):
            let clampedLevel = min(max(level, 0), 1)
            let steppedLevel = (clampedLevel / voiceLevelStep).rounded() * voiceLevelStep
            return min(restingBrightness + loudestVoiceBoost * steppedLevel, 1)
        case .alert:
            return 1
        }
    }
}

/// Everything the glow's window needs to draw one state. Equal appearances draw the same, so
/// the window is updated only when this changes.
public struct EdgeGlowAppearance: Sendable, Equatable {
    /// The colours turning around the screen.
    public let colours: [GlowColour]
    /// The steady brightness, 0…1.
    public let brightness: Double
    /// Whether the glow pulses (while Glim thinks or acts).
    public let pulses: Bool

    /// The appearance of `theme` while the orb is in `mood`; nil means screen chat is waiting.
    public init(theme: GlowTheme, mood: OrbMood?) {
        colours = theme.colours(for: mood ?? .listening(level: 0))
        brightness = EdgeGlowMotion.brightness(for: mood)
        pulses = mood == .thinking || mood == .acting
    }
}
