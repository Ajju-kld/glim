/// Which colours the screen glow uses.
public enum GlowStyle: String, Sendable, Equatable, Codable, CaseIterable {
    /// Glim's orb colours, changing with its mood.
    case orbColours
    /// A rainbow sweeping around the screen.
    case rainbow
    /// One steady colour.
    case singleColour
    /// Two to four colours the owner picked.
    case custom

    /// The name shown in the settings.
    public var displayName: String {
        switch self {
        case .orbColours: "Orb colours"
        case .rainbow: "Rainbow"
        case .singleColour: "Single colour"
        case .custom: "Custom"
        }
    }
}

/// The screen glow's saved look. A stop or block always glows in the orb's red, whatever the
/// theme, so it can't be mistaken for Glim simply listening.
public struct GlowTheme: Sendable, Equatable, Codable {
    /// Business rule: a custom glow needs at least two colours to flow between.
    public static let minimumCustomColours = 2
    /// Business rule: more than four colours turn the glow muddy.
    public static let maximumCustomColours = 4

    /// Business rule: the rainbow preset, red round to violet.
    static let rainbowColours = [
        GlowColour(red: 1.0, green: 0.3, blue: 0.3), GlowColour(red: 1.0, green: 0.6, blue: 0.2),
        GlowColour(red: 1.0, green: 0.9, blue: 0.3), GlowColour(red: 0.35, green: 0.9, blue: 0.45),
        GlowColour(red: 0.3, green: 0.65, blue: 1.0), GlowColour(red: 0.7, green: 0.4, blue: 1.0),
    ]
    /// Placeholder: the colours a new custom theme starts from, the orb's listening teal and
    /// violet.
    static let startingCustomColours = [
        GlowColour(red: 0.35, green: 0.95, blue: 1.0),
        GlowColour(red: 0.75, green: 0.35, blue: 1.0),
    ]

    /// The theme Glim starts with: the orb's colours.
    public static let standard = GlowTheme(
        style: .orbColours, singleColour: startingCustomColours[0],
        customColours: startingCustomColours)

    /// Which colours the glow uses.
    public var style: GlowStyle
    /// The colour for ``GlowStyle/singleColour``.
    public var singleColour: GlowColour
    /// The colours for ``GlowStyle/custom``, always two to four.
    public var customColours: [GlowColour] {
        didSet { customColours = Self.bounded(customColours) }
    }

    /// Creates a theme, keeping two to four custom colours.
    public init(style: GlowStyle, singleColour: GlowColour, customColours: [GlowColour]) {
        self.style = style
        self.singleColour = singleColour
        self.customColours = Self.bounded(customColours)
    }

    /// The colours to draw while the orb is in `mood`.
    public func colours(for mood: OrbMood) -> [GlowColour] {
        if mood == .alert {
            return OrbPalette.colours(for: .alert)
        }
        switch style {
        case .orbColours: return OrbPalette.colours(for: mood)
        case .rainbow: return Self.rainbowColours
        case .singleColour: return [singleColour]
        case .custom: return customColours
        }
    }

    private enum CodingKeys: String, CodingKey {
        case style, singleColour, customColours
    }

    /// Reads a saved theme; missing or unknown parts fall back to the standard theme's.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            style: (try? container.decode(GlowStyle.self, forKey: .style)) ?? Self.standard.style,
            singleColour: try container.decodeIfPresent(GlowColour.self, forKey: .singleColour)
                ?? Self.standard.singleColour,
            customColours: try container.decodeIfPresent([GlowColour].self, forKey: .customColours)
                ?? Self.standard.customColours)
    }

    /// Two to four colours: extra ones are dropped, missing ones filled from the starting pair.
    private static func bounded(_ colours: [GlowColour]) -> [GlowColour] {
        var boundedColours = Array(colours.prefix(maximumCustomColours))
        for fillColour in startingCustomColours where boundedColours.count < minimumCustomColours {
            boundedColours.append(fillColour)
        }
        return boundedColours
    }
}
