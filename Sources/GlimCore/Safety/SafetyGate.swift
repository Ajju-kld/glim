/// Decides whether one proposed action may run, needs the person's click, or is denied.
///
/// The model never acts; it only proposes. Every proposal passes the checks in the order listed
/// in the design spec (§9.2). The first denial wins and stops the task. Confirmation reasons
/// accumulate so the person sees all of them in one panel.
public struct SafetyGate: Sendable {
    private let policy: SafetyPolicy
    private let riskClassifier: RiskClassifier
    private let planMatcher = PlanMatcher()

    /// Creates a gate that enforces `policy`.
    public init(policy: SafetyPolicy) {
        self.policy = policy
        self.riskClassifier = RiskClassifier(wordLists: policy.riskWords)
    }

    /// Judges one proposed action against the approved step, the fresh screen and the policy.
    public func evaluate(_ context: GateContext) -> GateDecision {
        let action = context.proposedAction
        let tier = policy.appTrust.tier(for: action.targetApp)
        let permission = AppTrustPolicy.permission(for: action.kind, in: tier)
        let riskLevel = riskLevel(of: context)

        if let violation = firstViolation(
            in: context, tier: tier, permission: permission, riskLevel: riskLevel)
        {
            return .deny(violation)
        }
        let reasons = confirmationReasons(
            for: context, permission: permission, riskLevel: riskLevel)
        return reasons.isEmpty ? .allow : .needsConfirmation(reasons)
    }

    private func firstViolation(
        in context: GateContext,
        tier: TrustTier,
        permission: TierPermission,
        riskLevel: RiskLevel
    ) -> GuardViolation? {
        let action = context.proposedAction
        guard context.safetyState.isKillSwitchArmed else {
            return .killSwitchTripped
        }
        guard context.safetyState.isWatchdogAlive else {
            return .watchdogMissing
        }
        guard permission != .denied else {
            return .blockedByTier(
                appName: action.targetApp.displayName, tier: tier, action: action.kind)
        }
        // Opening launches the app's own code, so it must prove who it is.
        if action.kind == .openApp, !action.targetApp.hasValidSignature {
            return .unverifiedApp(appName: action.targetApp.displayName)
        }
        if let planViolation = planViolation(in: context) {
            return planViolation
        }
        if let targetViolation = targetViolation(in: context) {
            return targetViolation
        }
        if let textViolation = textViolation(in: context) {
            return textViolation
        }
        if let limitViolation = context.limitViolation {
            return .limitReached(limitViolation)
        }
        if case .forbidden(let matchedPhrase) = riskLevel {
            return .forbiddenAction(
                matchedPhrase: matchedPhrase, elementLabel: riskTargetLabel(of: context))
        }
        return nil
    }

    /// The action must be the approved step's kind, in the approved step's app.
    private func planViolation(in context: GateContext) -> GuardViolation? {
        let action = context.proposedAction
        let approvedStep = context.approvedStep
        let isSameKind = action.kind == approvedStep.action.kind
        let isSameApp = action.targetApp.bundleIdentifier == approvedStep.app?.bundleIdentifier
        guard isSameKind, isSameApp else {
            return .notInPlan(
                planned: approvedStep.action.summary,
                proposed: "\(action.kind.displayName) in \(action.targetApp.displayName)")
        }
        return nil
    }

    /// A chosen element must come from this step's fresh table and must not be a password field.
    private func targetViolation(in context: GateContext) -> GuardViolation? {
        let action = context.proposedAction
        guard action.kind.needsTargetElement else {
            return nil
        }
        guard let element = action.targetElement, context.currentElements.contains(element) else {
            let description =
                context.approvedStep.action.targetDescription ?? action.kind.displayName
            return .unknownTarget(description: description)
        }
        guard !element.isSecureTextField else {
            return .secureField(elementLabel: element.label)
        }
        return nil
    }

    /// Typed text must be exactly the approved text, within the length limit, and free of
    /// characters that act like key presses.
    private func textViolation(in context: GateContext) -> GuardViolation? {
        guard context.proposedAction.kind == .typeText else {
            return nil
        }
        guard let text = context.proposedAction.text,
            text == context.approvedStep.action.approvedText
        else {
            return .textMismatch
        }
        guard text.count <= policy.limits.maximumTypedTextLength else {
            return .textTooLong(limit: policy.limits.maximumTypedTextLength)
        }
        guard !TextSafety.containsKeyLikeCharacters(text) else {
            return .unsafeText
        }
        return nil
    }

    /// Risk words are checked on the chosen element and the approved target description — and,
    /// for Return, on whatever Return would activate.
    private func riskLevel(of context: GateContext) -> RiskLevel {
        if Self.isReturnKey(context.proposedAction) {
            return riskClassifier.classify(context.returnKeyTargetTexts)
        }
        guard context.proposedAction.kind.needsTargetElement else {
            return .safe
        }
        var texts = context.proposedAction.targetElement?.describingTexts ?? []
        if let targetDescription = context.approvedStep.action.targetDescription {
            texts.append(targetDescription)
        }
        return riskClassifier.classify(texts)
    }

    /// The label shown when a risk phrase matched: the chosen element, what Return activates,
    /// or the step itself.
    private func riskTargetLabel(of context: GateContext) -> String {
        if let elementLabel = context.proposedAction.targetElement?.label {
            return elementLabel
        }
        if Self.isReturnKey(context.proposedAction),
            let activatedControl = context.returnKeyTargetTexts.first
        {
            return activatedControl
        }
        return context.approvedStep.action.summary
    }

    private static func isReturnKey(_ action: ProposedAction) -> Bool {
        action.kind == .pressKey && action.key == .returnKey
    }

    private func confirmationReasons(
        for context: GateContext, permission: TierPermission, riskLevel: RiskLevel
    ) -> [ConfirmationReason] {
        let action = context.proposedAction
        var reasons: [ConfirmationReason] = []
        if case .needsConfirmation(let matchedPhrase) = riskLevel {
            reasons.append(
                .riskyWord(matchedPhrase: matchedPhrase, elementLabel: riskTargetLabel(of: context))
            )
        }
        if Self.isReturnKey(action) {
            reasons.append(.pressReturn(activates: context.returnKeyTargetTexts.first))
        }
        if let element = action.targetElement,
            let plannedTarget = context.approvedStep.action.targetDescription,
            !planMatcher.elementMatchesPlan(targetDescription: plannedTarget, element: element)
        {
            reasons.append(.planMismatch(planned: plannedTarget, chosen: element.label))
        }
        reasons.append(contentsOf: context.checkerConcerns)
        if permission == .allowedWithConfirmation {
            let appName = action.targetApp.displayName
            let tierReason: ConfirmationReason =
                action.kind == .quitApp
                ? .quitApp(appName: appName) : .supervisedApp(appName: appName)
            reasons.append(tierReason)
        }
        return reasons
    }
}
