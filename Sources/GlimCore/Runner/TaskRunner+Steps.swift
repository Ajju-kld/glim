import Foundation

/// Running one approved step: resolve the app, read the screen, pick and check the target,
/// ask the gate, confirm if needed, act, and verify that something changed.
extension TaskRunner {
    func runStep(
        _ step: ScreenedStep,
        of plan: ScreenedPlan,
        limiter: inout ActionLimiter,
        takeoverSupervisor: TakeoverSupervisor,
        onEvent: @escaping @Sendable (TaskEvent) -> Void
    ) async throws {
        try ensureArmed()
        let policy = currentPolicy
        let gate = SafetyGate(policy: policy)
        limiter.updateLimits(policy.limits)
        onEvent(
            .acting(
                stepNumber: step.number, totalSteps: plan.steps.count, summary: step.action.summary)
        )
        if case .speak(let text) = step.action {
            await dependencies.narrator.say(text)
            return
        }
        let app = try resolveForExecution(step)
        try ensureRunsInApprovedApp(app, step: step, policy: policy)
        await dependencies.narrator.say(step.action.summary)

        let snapshotBefore = Self.readsScreen(step.action) ? try await snapshot(of: app) : nil
        var target: UIElementSnapshot?
        var checkerConcerns: [ConfirmationReason] = []
        if step.action.kind.needsTargetElement, let snapshotBefore {
            (target, checkerConcerns) = try await chooseTarget(
                for: step, goal: plan.goal, snapshot: snapshotBefore, limiter: &limiter)
        }
        try await pause(for: limiter.waitBeforeNextAction(at: .now))

        let returnKeyTargetTexts = await returnKeyTargetTexts(for: step.action, in: app)
        let decision = gate.evaluate(
            gateContext(
                for: step, app: app, target: target, elements: snapshotBefore?.table.elements ?? [],
                limiter: limiter, checkerConcerns: checkerConcerns,
                returnKeyTargetTexts: returnKeyTargetTexts))
        try await audit(.gateDecision, "\(step.action.summary): \(decision)")
        var executionTarget = target
        switch decision {
        case .allow:
            break
        case .deny(let violation):
            throw RunnerStop.blocked(violation, stepNumber: step.number)
        case .needsConfirmation(let reasons):
            let request = ConfirmationRequest(
                step: step, appName: app.identity.displayName,
                elementLabel: target?.label ?? returnKeyTargetTexts.first,
                textToType: step.action.approvedText, reasons: reasons)
            try await askPerson(request, takeoverSupervisor: takeoverSupervisor, onEvent: onEvent)
            executionTarget = try await recheckAfterConfirmation(
                of: step, app: app, target: target, confirmedReasons: reasons,
                checkerConcerns: checkerConcerns, limiter: limiter)
        }

        try ensureArmed()
        do {
            try await dependencies.executor.perform(
                ExecutableAction(step: step.action, app: app, targetElement: target))
        } catch .stopped {
            throw RunnerStop.stopped(dependencies.killSwitch.tripReason ?? .stopButton)
        } catch {
            try await audit(.actionFailed, error.explanation)
            throw RunnerStop.failed(error.explanation)
        }
        try await audit(.actionPerformed, step.action.summary)

        if case .openApp(let appName) = step.action {
            try await waitForAppToLaunch(named: appName)
        }
        try await pause(for: timing.settleAfterAction)
        let changedScreen = try await screenChanged(after: step, in: app, before: snapshotBefore)
        limiter.recordAction(at: .now, changedScreen: changedScreen)
        limiter.beginNextStep()
    }

    private func askPerson(
        _ request: ConfirmationRequest,
        takeoverSupervisor: TakeoverSupervisor,
        onEvent: @escaping @Sendable (TaskEvent) -> Void
    ) async throws {
        takeoverSupervisor.stop()
        onEvent(.awaitingConfirmation(request))
        let allowed = await dependencies.decisions.confirmAction(request)
        try await audit(.confirmationAnswered, allowed ? "Allowed once" : "Stopped")
        guard allowed else {
            dependencies.killSwitch.trip(.panelCancelled)
            throw RunnerStop.stopped(.panelCancelled)
        }
        try ensureArmed()
        takeoverSupervisor.start()
    }

    /// The person may take up to a minute to decide, so everything is checked again before
    /// acting: a fresh screen, the same control, the kill switch, the watchdog, the limits, and
    /// what Return would activate. Anything the person did not already see stops the task.
    private func recheckAfterConfirmation(
        of step: ScreenedStep,
        app: ResolvedApp,
        target: UIElementSnapshot?,
        confirmedReasons: [ConfirmationReason],
        checkerConcerns: [ConfirmationReason],
        limiter: ActionLimiter
    ) async throws -> UIElementSnapshot? {
        var freshTarget = target
        var freshElements: [UIElementSnapshot] = []
        if Self.readsScreen(step.action) {
            freshElements = try await snapshot(of: app).table.elements
            if let target {
                guard
                    let sameControl = freshElements.first(where: {
                        $0.identifiesSameControl(as: target)
                    })
                else {
                    throw RunnerStop.blocked(
                        .changedWhileWaiting(description: target.label), stepNumber: step.number)
                }
                freshTarget = sameControl
            }
        }
        let decision = SafetyGate(policy: currentPolicy).evaluate(
            gateContext(
                for: step, app: app, target: freshTarget, elements: freshElements, limiter: limiter,
                checkerConcerns: checkerConcerns,
                returnKeyTargetTexts: await returnKeyTargetTexts(for: step.action, in: app)))
        try await audit(.gateDecision, "After confirmation — \(step.action.summary): \(decision)")
        switch decision {
        case .allow:
            return freshTarget
        case .deny(let violation):
            throw RunnerStop.blocked(violation, stepNumber: step.number)
        case .needsConfirmation(let reasons):
            guard reasons.allSatisfy(confirmedReasons.contains) else {
                throw RunnerStop.blocked(
                    .changedWhileWaiting(description: step.action.summary), stepNumber: step.number)
            }
            return freshTarget
        }
    }

    private func gateContext(
        for step: ScreenedStep,
        app: ResolvedApp,
        target: UIElementSnapshot?,
        elements: [UIElementSnapshot],
        limiter: ActionLimiter,
        checkerConcerns: [ConfirmationReason],
        returnKeyTargetTexts: [String]
    ) -> GateContext {
        GateContext(
            approvedStep: step,
            proposedAction: ProposedAction(
                kind: step.action.kind, targetApp: app.identity, targetElement: target,
                text: step.action.approvedText, key: Self.key(of: step.action)),
            currentElements: elements,
            limitViolation: limiter.violation(at: .now),
            checkerConcerns: checkerConcerns,
            safetyState: SafetyState(
                isKillSwitchArmed: dependencies.killSwitch.isArmed,
                isWatchdogAlive: dependencies.isWatchdogAlive()),
            returnKeyTargetTexts: returnKeyTargetTexts)
    }

    private func returnKeyTargetTexts(for action: StepAction, in app: ResolvedApp) async -> [String]
    {
        guard Self.key(of: action) == .returnKey else {
            return []
        }
        return await dependencies.screenReader.returnKeyTargetTexts(in: app)
    }

    /// The app found at run time must be the approved one, and its tier must still allow the
    /// step — checked before its screen is read or sent to any checker.
    private func ensureRunsInApprovedApp(
        _ app: ResolvedApp, step: ScreenedStep, policy: SafetyPolicy
    ) throws {
        guard app.identity.bundleIdentifier == step.app?.bundleIdentifier else {
            throw RunnerStop.blocked(
                .notInPlan(
                    planned: step.action.summary, proposed: "act in \(app.identity.displayName)"),
                stepNumber: step.number)
        }
        let tier = policy.appTrust.tier(for: app.identity)
        guard AppTrustPolicy.permission(for: step.action.kind, in: tier) != .denied else {
            throw RunnerStop.blocked(
                .blockedByTier(
                    appName: app.identity.displayName, tier: tier, action: step.action.kind),
                stepNumber: step.number)
        }
    }

    private static func readsScreen(_ action: StepAction) -> Bool {
        action.kind.needsTargetElement || action.kind == .pressKey || action.kind == .scroll
    }

    // MARK: - Target choice

    private func chooseTarget(
        for step: ScreenedStep, goal: String, snapshot: ScreenSnapshot, limiter: inout ActionLimiter
    ) async throws -> (UIElementSnapshot, [ConfirmationReason]) {
        var retryNote: String?
        while true {
            if let violation = limiter.violation(at: .now),
                violation
                    != .actionsTooClose(
                        minimumSeconds: currentPolicy.limits.minimumSecondsBetweenActions)
            {
                throw RunnerStop.blocked(.limitReached(violation), stepNumber: step.number)
            }
            let choice: TargetChoice
            do {
                choice = try await dependencies.planner.pickTarget(
                    for: step.action, goal: goal, among: snapshot.table.elements,
                    retryNote: retryNote)
            } catch .model(let modelError) {
                throw RunnerStop.failed(modelError.explanation)
            } catch {
                limiter.recordModelError()
                retryNote = error.explanation
                try await audit(.modelError, error.explanation)
                continue
            }
            switch choice {
            case .blocked(let reason):
                try await audit(.modelError, "The AI found no matching control: \(reason)")
                let description = step.action.targetDescription ?? step.action.summary
                throw RunnerStop.blocked(
                    .unknownTarget(description: description), stepNumber: step.number)
            case .element(let element):
                let concerns = try await checkerConcerns(
                    for: step, goal: goal, snapshot: snapshot, chosen: element)
                return (element, concerns)
            }
        }
    }

    private func checkerConcerns(
        for step: ScreenedStep, goal: String, snapshot: ScreenSnapshot, chosen: UIElementSnapshot
    ) async throws -> [ConfirmationReason] {
        let result = await dependencies.checkerConsensus.review(
            TargetReviewRequest(
                goal: goal, step: step, windowTitle: snapshot.windowTitle,
                candidates: ElementRoles.candidates(
                    in: snapshot.table.elements, for: step.action.kind),
                chosenElement: chosen))
        for outcome in result.outcomes {
            try await audit(.checkerVerdict, "\(outcome.checkerName): \(outcome.verdict)")
        }
        return result.concerns
    }

    // MARK: - Apps and screens

    private func resolveForExecution(_ step: ScreenedStep) throws -> ResolvedApp {
        guard let appName = step.action.appName else {
            throw RunnerStop.failed("This step has no app.")
        }
        let resolvedApp =
            step.action.kind == .openApp
            ? dependencies.appResolver.resolve(appNamed: appName)
            : dependencies.appResolver.resolveRunning(appNamed: appName)
        guard let resolvedApp else {
            throw RunnerStop.blocked(.unknownTarget(description: appName), stepNumber: step.number)
        }
        return resolvedApp
    }

    private func snapshot(of app: ResolvedApp) async throws -> ScreenSnapshot {
        do {
            return try await dependencies.screenReader.snapshotFrontWindow(of: app)
        } catch {
            throw RunnerStop.failed(error.explanation)
        }
    }

    private func waitForAppToLaunch(named appName: String) async throws {
        let deadline = ContinuousClock.now + timing.appLaunchTimeout
        while dependencies.appResolver.resolveRunning(appNamed: appName) == nil {
            guard ContinuousClock.now < deadline else {
                throw RunnerStop.failed("\(appName) didn't finish opening.")
            }
            try await pause(for: timing.appLaunchPollInterval)
        }
    }

    /// Whether the step visibly changed something. App and window actions report success
    /// themselves; in-app actions compare the window before and after. Glim never repeats an
    /// action automatically (a repeated click could send twice); unchanged steps count toward
    /// the no-change limit instead.
    private func screenChanged(
        after step: ScreenedStep, in app: ResolvedApp, before: ScreenSnapshot?
    ) async throws -> Bool {
        guard let before,
            let runningApp = dependencies.appResolver.resolveRunning(
                appNamed: app.identity.displayName)
        else {
            return true
        }
        let after: ScreenSnapshot
        do {
            after = try await dependencies.screenReader.snapshotFrontWindow(of: runningApp)
        } catch {
            return false
        }
        if let typedText = step.action.approvedText,
            after.table.elements.contains(where: { $0.value?.contains(typedText) == true })
        {
            return true
        }
        return after.table != before.table || after.windowTitle != before.windowTitle
    }

    private static func key(of action: StepAction) -> AllowedKey? {
        if case .pressKey(_, let key) = action {
            return key
        }
        return nil
    }
}
