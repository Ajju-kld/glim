extension SafetyPolicy {
    /// The stricter of two policies, rule by rule: the lower tier for every app, every phrase from
    /// both lists, the tighter value of every limit, and auto-run only if both allow it.
    ///
    /// A running task combines the policy it started with and the current one, so a tightening
    /// applies at once while a loosening can't reach a task that is already running.
    public func combinedStrictly(with other: SafetyPolicy) -> SafetyPolicy {
        SafetyPolicy(
            limits: limits.combinedStrictly(with: other.limits),
            riskWords: RiskWordLists(
                forbidden: Self.union(riskWords.forbidden, other.riskWords.forbidden),
                confirm: Self.union(riskWords.confirm, other.riskWords.confirm)),
            appTrust: appTrust.combinedStrictly(with: other.appTrust),
            asksOnlyBeforeDangerousSteps: asksOnlyBeforeDangerousSteps
                && other.asksOnlyBeforeDangerousSteps)
    }

    /// Phrases from both lists, in order, without repeating a phrase that normalizes the same.
    private static func union(_ firstPhrases: [String], _ secondPhrases: [String]) -> [String] {
        var seenPhrases = Set<String>()
        return (firstPhrases + secondPhrases).filter { phrase in
            seenPhrases.insert(RiskClassifier.normalize(phrase)).inserted
        }
    }
}

extension SafetyLimits {
    /// The tighter value of every limit.
    func combinedStrictly(with other: SafetyLimits) -> SafetyLimits {
        SafetyLimits(
            maximumActionsPerTask: min(maximumActionsPerTask, other.maximumActionsPerTask),
            maximumTriesPerStep: min(maximumTriesPerStep, other.maximumTriesPerStep),
            minimumSecondsBetweenActions: max(
                minimumSecondsBetweenActions, other.minimumSecondsBetweenActions),
            taskTimeoutSeconds: min(taskTimeoutSeconds, other.taskTimeoutSeconds),
            maximumConsecutiveUnchangedActions: min(
                maximumConsecutiveUnchangedActions, other.maximumConsecutiveUnchangedActions),
            maximumTypedTextLength: min(maximumTypedTextLength, other.maximumTypedTextLength))
    }
}

extension AppTrustPolicy {
    /// The lower tier for every app either policy lists, and the lower default tier.
    func combinedStrictly(with other: AppTrustPolicy) -> AppTrustPolicy {
        let bundleIdentifiers = Set(tiersByBundleIdentifier.keys).union(
            other.tiersByBundleIdentifier.keys)
        var combinedTiers: [String: TrustTier] = [:]
        for bundleIdentifier in bundleIdentifiers {
            let firstTier = tiersByBundleIdentifier[bundleIdentifier] ?? defaultTier
            let secondTier = other.tiersByBundleIdentifier[bundleIdentifier] ?? other.defaultTier
            combinedTiers[bundleIdentifier] = min(firstTier, secondTier)
        }
        return AppTrustPolicy(
            tiersByBundleIdentifier: combinedTiers, defaultTier: min(defaultTier, other.defaultTier)
        )
    }
}
