/// Everything the safety gate enforces: limits, risk phrases, app trust tiers, and whether Glim
/// asks only before dangerous steps.
public struct SafetyPolicy: Sendable, Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case limits, riskWords, appTrust, asksOnlyBeforeDangerousSteps
    }

    /// The defaults agreed in the design. "Reset to safe defaults" restores exactly this.
    public static let safeDefaults = SafetyPolicy(
        limits: .safeDefaults,
        riskWords: RiskWordLists(
            forbidden: SafetyDefaults.forbiddenPhrases,
            confirm: SafetyDefaults.confirmPhrases),
        appTrust: AppTrustPolicy(
            tiersByBundleIdentifier: SafetyDefaults.appTiers,
            defaultTier: .readOnly),
        asksOnlyBeforeDangerousSteps: true)

    /// Numeric limits for one task.
    public var limits: SafetyLimits
    /// Forbidden and Confirm phrases.
    public var riskWords: RiskWordLists
    /// Trust tier per app.
    public var appTrust: AppTrustPolicy
    /// Business rule (owner's request, 2026-09-23): plans start without the approval panel and
    /// Glim asks only at a dangerous step — a Confirm phrase, Return, quitting, or a supervised
    /// app (``ConfirmationReason/isDangerous``). Forbidden steps are still blocked. When off,
    /// every plan waits for Approve and every confirmation reason asks.
    public var asksOnlyBeforeDangerousSteps: Bool

    /// Creates a policy.
    public init(
        limits: SafetyLimits, riskWords: RiskWordLists, appTrust: AppTrustPolicy,
        asksOnlyBeforeDangerousSteps: Bool
    ) {
        self.limits = limits
        self.riskWords = riskWords
        self.appTrust = appTrust
        self.asksOnlyBeforeDangerousSteps = asksOnlyBeforeDangerousSteps
    }

    /// Reads a saved policy. Settings sealed before `asksOnlyBeforeDangerousSteps` existed get
    /// the default, so they load instead of looking damaged.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        limits = try container.decode(SafetyLimits.self, forKey: .limits)
        riskWords = try container.decode(RiskWordLists.self, forKey: .riskWords)
        appTrust = try container.decode(AppTrustPolicy.self, forKey: .appTrust)
        asksOnlyBeforeDangerousSteps =
            try container.decodeIfPresent(Bool.self, forKey: .asksOnlyBeforeDangerousSteps)
            ?? Self.safeDefaults.asksOnlyBeforeDangerousSteps
    }
}
