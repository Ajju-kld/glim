/// The orb's colours for each mood, bright to deep. The notch orb and the screen glow share them.
public enum OrbPalette {
    /// Four colours for `mood`.
    public static func colours(for mood: OrbMood) -> [GlowColour] {
        switch mood {
        case .listening:
            [
                GlowColour(red: 0.35, green: 0.95, blue: 1.0),
                GlowColour(red: 0.3, green: 0.45, blue: 1.0),
                GlowColour(red: 0.75, green: 0.35, blue: 1.0),
                GlowColour(red: 1.0, green: 0.45, blue: 0.8),
            ]
        case .thinking:
            [
                GlowColour(red: 0.95, green: 0.4, blue: 1.0),
                GlowColour(red: 0.45, green: 0.3, blue: 1.0),
                GlowColour(red: 1.0, green: 0.5, blue: 0.55),
                GlowColour(red: 0.3, green: 0.75, blue: 1.0),
            ]
        case .acting:
            [
                GlowColour(red: 0.4, green: 1.0, blue: 0.75),
                GlowColour(red: 0.1, green: 0.75, blue: 0.85),
                GlowColour(red: 0.35, green: 0.55, blue: 1.0),
                GlowColour(red: 0.7, green: 1.0, blue: 0.5),
            ]
        case .waiting:
            [
                GlowColour(red: 1.0, green: 0.8, blue: 0.3),
                GlowColour(red: 1.0, green: 0.5, blue: 0.25),
                GlowColour(red: 1.0, green: 0.4, blue: 0.55),
                GlowColour(red: 1.0, green: 0.9, blue: 0.6),
            ]
        case .done:
            [
                GlowColour(red: 0.45, green: 1.0, blue: 0.6),
                GlowColour(red: 0.15, green: 0.75, blue: 0.55),
                GlowColour(red: 0.4, green: 0.9, blue: 0.9),
                GlowColour(red: 0.8, green: 1.0, blue: 0.7),
            ]
        case .alert:
            [
                GlowColour(red: 1.0, green: 0.35, blue: 0.35),
                GlowColour(red: 0.8, green: 0.1, blue: 0.25),
                GlowColour(red: 1.0, green: 0.55, blue: 0.3),
                GlowColour(red: 1.0, green: 0.3, blue: 0.5),
            ]
        }
    }
}
