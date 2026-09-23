/// Everything the safety gate enforces: limits, risk phrases and app trust tiers.
public struct SafetyPolicy: Sendable, Equatable, Codable {
    /// The defaults agreed in the design. "Reset to safe defaults" restores exactly this.
    public static let safeDefaults = SafetyPolicy(
        limits: .safeDefaults,
        riskWords: RiskWordLists(
            forbidden: SafetyDefaults.forbiddenPhrases,
            confirm: SafetyDefaults.confirmPhrases),
        appTrust: AppTrustPolicy(
            tiersByBundleIdentifier: SafetyDefaults.appTiers,
            defaultTier: .readOnly))

    /// Numeric limits for one task.
    public var limits: SafetyLimits
    /// Forbidden and Confirm phrases.
    public var riskWords: RiskWordLists
    /// Trust tier per app.
    public var appTrust: AppTrustPolicy

    /// Creates a policy.
    public init(limits: SafetyLimits, riskWords: RiskWordLists, appTrust: AppTrustPolicy) {
        self.limits = limits
        self.riskWords = riskWords
        self.appTrust = appTrust
    }
}
