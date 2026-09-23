/// Everything the safety gate enforces: limits, risk phrases, app trust tiers, and whether
/// low-risk plans start without the approval panel.
public struct SafetyPolicy: Sendable, Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case limits, riskWords, appTrust, autoRunsLowRiskPlans
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
        autoRunsLowRiskPlans: true)

    /// Numeric limits for one task.
    public var limits: SafetyLimits
    /// Forbidden and Confirm phrases.
    public var riskWords: RiskWordLists
    /// Trust tier per app.
    public var appTrust: AppTrustPolicy
    /// Business rule (owner's request, 2026-09-23): a plan whose every step is low-risk starts
    /// at once instead of waiting for Approve (see ``LowRiskPlanRule``). Risky steps still ask.
    public var autoRunsLowRiskPlans: Bool

    /// Creates a policy.
    public init(
        limits: SafetyLimits, riskWords: RiskWordLists, appTrust: AppTrustPolicy,
        autoRunsLowRiskPlans: Bool
    ) {
        self.limits = limits
        self.riskWords = riskWords
        self.appTrust = appTrust
        self.autoRunsLowRiskPlans = autoRunsLowRiskPlans
    }

    /// Reads a saved policy. Settings sealed before `autoRunsLowRiskPlans` existed get the
    /// default, so they load instead of looking damaged.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        limits = try container.decode(SafetyLimits.self, forKey: .limits)
        riskWords = try container.decode(RiskWordLists.self, forKey: .riskWords)
        appTrust = try container.decode(AppTrustPolicy.self, forKey: .appTrust)
        autoRunsLowRiskPlans =
            try container.decodeIfPresent(Bool.self, forKey: .autoRunsLowRiskPlans)
            ?? Self.safeDefaults.autoRunsLowRiskPlans
    }
}
