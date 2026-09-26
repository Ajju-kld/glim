/// Everything the person can change in the control panel.
public struct GlimSettings: Sendable, Equatable, Codable {
    /// Tunable (B-Q12, C-8): the Ollama model that plans and picks targets. `qwen3-vl:4b` for
    /// now: `qwen3-vl:8b` plans better but needs about 2 GB more memory, and a 16 GB Mac under
    /// memory pressure ran it at 3–6 tokens a second.
    public static let defaultPlannerModelName = "qwen3-vl:4b"

    /// The settings Glim starts with and "Reset to safe defaults" restores.
    public static let safeDefaults = GlimSettings(
        safetyPolicy: .safeDefaults,
        jev: .safeDefaults,
        plannerModelName: defaultPlannerModelName,
        isNarrationMuted: false)

    /// Limits, risk phrases and app tiers.
    public var safetyPolicy: SafetyPolicy
    /// The optional cloud checker.
    public var jev: JevSettings
    /// The Ollama model name.
    public var plannerModelName: String
    /// Whether Glim stays silent instead of narrating each step.
    public var isNarrationMuted: Bool
    /// Whether steps Laya reviewed are kept on this Mac as training examples. Off until the
    /// owner turns it on.
    public var savesLayaExamples: Bool
    /// The screen glow's look during screen chat. Changing it doesn't touch safety.
    public var glowTheme: GlowTheme

    /// Creates settings.
    public init(
        safetyPolicy: SafetyPolicy,
        jev: JevSettings,
        plannerModelName: String,
        isNarrationMuted: Bool,
        savesLayaExamples: Bool = false,
        glowTheme: GlowTheme = .standard
    ) {
        self.safetyPolicy = safetyPolicy
        self.jev = jev
        self.plannerModelName = plannerModelName
        self.isNarrationMuted = isNarrationMuted
        self.savesLayaExamples = savesLayaExamples
        self.glowTheme = glowTheme
    }

    private enum CodingKeys: String, CodingKey {
        case safetyPolicy, jev, plannerModelName, isNarrationMuted, savesLayaExamples, glowTheme
    }

    /// Reads saved settings; files written before a setting existed get its default.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        safetyPolicy = try container.decode(SafetyPolicy.self, forKey: .safetyPolicy)
        jev = try container.decode(JevSettings.self, forKey: .jev)
        plannerModelName = try container.decode(String.self, forKey: .plannerModelName)
        isNarrationMuted = try container.decode(Bool.self, forKey: .isNarrationMuted)
        savesLayaExamples =
            try container.decodeIfPresent(Bool.self, forKey: .savesLayaExamples) ?? false
        glowTheme = try container.decodeIfPresent(GlowTheme.self, forKey: .glowTheme) ?? .standard
    }
}
