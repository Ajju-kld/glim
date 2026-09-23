/// Lists every way a settings change loosens safety or privacy. Tightening changes produce an
/// empty list and apply without Touch ID.
public enum SafetyChangeClassifier {
    /// The loosenings made by changing `oldSettings` into `newSettings`, in a stable order.
    public static func loosenings(
        from oldSettings: GlimSettings, to newSettings: GlimSettings
    ) -> [SettingsLoosening] {
        let oldPolicy = oldSettings.safetyPolicy
        let newPolicy = newSettings.safetyPolicy
        var loosenings: [SettingsLoosening] = []

        loosenings += removedPhrases(
            from: oldPolicy.riskWords.forbidden, to: newPolicy.riskWords.forbidden
        ).map { .removedForbiddenPhrase($0) }
        loosenings += removedPhrases(
            from: oldPolicy.riskWords.confirm, to: newPolicy.riskWords.confirm
        ).map { .removedConfirmPhrase($0) }

        if newPolicy.appTrust.defaultTier > oldPolicy.appTrust.defaultTier {
            loosenings.append(
                .defaultTierLoosened(
                    from: oldPolicy.appTrust.defaultTier, to: newPolicy.appTrust.defaultTier))
        }
        loosenings += loosenedAppTiers(from: oldPolicy.appTrust, to: newPolicy.appTrust)
        loosenings += loosenedLimits(from: oldPolicy.limits, to: newPolicy.limits)
            .map { .limitLoosened($0) }

        if newSettings.jev.isEnabled, !oldSettings.jev.isEnabled {
            loosenings.append(.jevEnabled)
        }
        loosenings += oldSettings.jev.excludedBundleIdentifiers
            .subtracting(newSettings.jev.excludedBundleIdentifiers)
            .sorted()
            .map { .jevExclusionRemoved(bundleIdentifier: $0) }
        // The model decides what is planned and where data is processed, so any change counts.
        if newSettings.plannerModelName != oldSettings.plannerModelName {
            loosenings.append(
                .plannerModelChanged(
                    from: oldSettings.plannerModelName, to: newSettings.plannerModelName))
        }
        return loosenings
    }

    /// Phrases in the old list whose normalized form no longer appears in the new list, so
    /// changing only letter case or spacing is not a loosening.
    private static func removedPhrases(from oldPhrases: [String], to newPhrases: [String])
        -> [String]
    {
        let remainingPhrases = Set(newPhrases.map(RiskClassifier.normalize))
        return oldPhrases.filter { !remainingPhrases.contains(RiskClassifier.normalize($0)) }
    }

    private static func loosenedAppTiers(
        from oldTrust: AppTrustPolicy, to newTrust: AppTrustPolicy
    ) -> [SettingsLoosening] {
        let bundleIdentifiers = Set(oldTrust.tiersByBundleIdentifier.keys)
            .union(newTrust.tiersByBundleIdentifier.keys)
        return bundleIdentifiers.sorted().compactMap { bundleIdentifier in
            let previousTier =
                oldTrust.tiersByBundleIdentifier[bundleIdentifier] ?? oldTrust.defaultTier
            let newTier = newTrust.tiersByBundleIdentifier[bundleIdentifier] ?? newTrust.defaultTier
            guard newTier > previousTier else {
                return nil
            }
            return .appMovedToLessRestrictiveTier(
                bundleIdentifier: bundleIdentifier, from: previousTier, to: newTier)
        }
    }

    private static func loosenedLimits(
        from oldLimits: SafetyLimits, to newLimits: SafetyLimits
    ) -> [SafetyLimitName] {
        var loosenedLimitNames: [SafetyLimitName] = []
        if newLimits.maximumActionsPerTask > oldLimits.maximumActionsPerTask {
            loosenedLimitNames.append(.maximumActionsPerTask)
        }
        if newLimits.maximumTriesPerStep > oldLimits.maximumTriesPerStep {
            loosenedLimitNames.append(.maximumTriesPerStep)
        }
        if newLimits.minimumSecondsBetweenActions < oldLimits.minimumSecondsBetweenActions {
            loosenedLimitNames.append(.minimumSecondsBetweenActions)
        }
        if newLimits.taskTimeoutSeconds > oldLimits.taskTimeoutSeconds {
            loosenedLimitNames.append(.taskTimeoutSeconds)
        }
        if newLimits.maximumConsecutiveUnchangedActions
            > oldLimits.maximumConsecutiveUnchangedActions
        {
            loosenedLimitNames.append(.maximumConsecutiveUnchangedActions)
        }
        if newLimits.maximumTypedTextLength > oldLimits.maximumTypedTextLength {
            loosenedLimitNames.append(.maximumTypedTextLength)
        }
        return loosenedLimitNames
    }
}
