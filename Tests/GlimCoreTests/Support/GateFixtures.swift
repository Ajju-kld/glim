@testable import GlimCore

extension SafetyState {
    static let allClear = SafetyState(isKillSwitchArmed: true, isWatchdogAlive: true)
}

/// Builds a gate context for an approved step in `stepApp`, with sensible defaults.
func makeGateContext(
    step: StepAction,
    stepApp: AppIdentity = .notes,
    proposedAction: ProposedAction,
    currentElements: [UIElementSnapshot] = [],
    limitViolation: LimitViolation? = nil,
    checkerConcerns: [ConfirmationReason] = [],
    safetyState: SafetyState = .allClear
) -> GateContext {
    let approvedStep = ScreenedStep(
        number: 1,
        action: step,
        app: stepApp,
        tier: SafetyPolicy.safeDefaults.appTrust.tier(for: stepApp))
    return GateContext(
        approvedStep: approvedStep,
        proposedAction: proposedAction,
        currentElements: currentElements,
        limitViolation: limitViolation,
        checkerConcerns: checkerConcerns,
        safetyState: safetyState)
}
