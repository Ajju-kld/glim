/// Everything the person can change in the control panel.
public struct GlimSettings: Sendable, Equatable, Codable {
    /// Tunable (B-Q12): the Ollama model that plans and picks targets.
    public static let defaultPlannerModelName = "qwen3-vl:8b"

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

    /// Creates settings.
    public init(
        safetyPolicy: SafetyPolicy,
        jev: JevSettings,
        plannerModelName: String,
        isNarrationMuted: Bool
    ) {
        self.safetyPolicy = safetyPolicy
        self.jev = jev
        self.plannerModelName = plannerModelName
        self.isNarrationMuted = isNarrationMuted
    }
}
