import Foundation

/// Running one approved step: resolve the app, read the screen, pick and check the target,
/// ask the gate, confirm if needed, act, and verify that something changed.
extension TaskRunner {
    func runStep(
        _ step: ScreenedStep,
        of plan: ScreenedPlan,
        limiter: inout ActionLimiter,
        latestScreen: inout ScreenSnapshot?,
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
        var timings = StepTimings()

        // The window read right after the previous step is fresh; reading it again would only
        // add time. The chosen control is still re-checked on screen right before acting.
        let reusableScreen = latestScreen.flatMap { screen in
            screen.app.processIdentifier == app.processIdentifier ? screen : nil
        }
        latestScreen = nil
        var snapshotBefore: ScreenSnapshot?
        if Self.readsScreen(step.action) {
            if let reusableScreen {
                snapshotBefore = reusableScreen
            } else {
                snapshotBefore = try await timings.measure("read window") {
                    try await snapshot(of: app)
                }
            }
        }
        var target: UIElementSnapshot?
        var targetPickedBy: PickSource?
        var visualClick: VisualClick?
        var checkerConcerns: [ConfirmationReason] = []
        if step.action.kind.needsTargetElement, let snapshotBefore {
            switch try await chooseTarget(
                for: step, goal: plan.goal, snapshot: snapshotBefore, limiter: &limiter,
                timings: &timings)
            {
            case .element(let element, let pickedBy, let concerns):
                target = element
                targetPickedBy = pickedBy
                checkerConcerns = concerns
            case .sight(let click):
                visualClick = click
            }
        }
        try await pause(for: limiter.waitBeforeNextAction(at: .now))

        let returnKeyTargetTexts = await returnKeyTargetTexts(for: step.action, in: app)
        let decision = gate.evaluate(
            gateContext(
                for: step, app: app, target: target, visualTarget: visualClick?.target,
                elements: snapshotBefore?.table.elements ?? [], limiter: limiter,
                checkerConcerns: checkerConcerns, returnKeyTargetTexts: returnKeyTargetTexts,
                returnKeyStaysInBrowserAddressBar: await returnKeyStaysInBrowserAddressBar(
                    for: step.action, in: app)))
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
                textToType: step.action.approvedText, reasons: reasons, visualClick: visualClick)
            try await timings.measure("waiting for you") {
                try await askPerson(
                    request, takeoverSupervisor: takeoverSupervisor, onEvent: onEvent)
            }
            executionTarget = try await recheckAfterConfirmation(
                of: step, app: app, target: target, visualTarget: visualClick?.target,
                confirmedReasons: reasons, checkerConcerns: checkerConcerns, limiter: limiter)
        }

        try ensureArmed()
        let actionStart = ContinuousClock.now
        do {
            try await dependencies.executor.perform(
                ExecutableAction(
                    step: step.action, app: app, targetElement: executionTarget,
                    visualTarget: visualClick?.target))
        } catch .stopped {
            throw RunnerStop.stopped(dependencies.killSwitch.tripReason ?? .stopButton)
        } catch {
            try await audit(.actionFailed, error.explanation)
            throw RunnerStop.failed(error.explanation)
        }
        try await audit(
            .actionPerformed,
            visualClick.map { Self.clickedBySightSummary($0.target, in: app) }
                ?? Self.performedSummary(
                    of: step.action, on: executionTarget, pickedBy: targetPickedBy))
        timings.record("act", ContinuousClock.now - actionStart)

        if case .openApp(let appName) = step.action {
            try await waitForAppToLaunch(named: appName)
        }
        try await pause(for: timing.settleAfterAction)
        let (changedScreen, screenAfter) = try await timings.measure("confirm change") {
            () async throws -> (changed: Bool, screenAfter: ScreenSnapshot?) in
            if let visualClick {
                return (try await windowImageChanged(in: app, since: visualClick), nil)
            }
            return try await screenChanged(after: step, in: app, before: snapshotBefore)
        }
        try await audit(.stepTiming, timings.summary(title: step.action.summary))
        latestScreen = screenAfter
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
        visualTarget: VisualTarget?,
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
                for: step, app: app, target: freshTarget, visualTarget: visualTarget,
                elements: freshElements, limiter: limiter, checkerConcerns: checkerConcerns,
                returnKeyTargetTexts: await returnKeyTargetTexts(for: step.action, in: app),
                returnKeyStaysInBrowserAddressBar: await returnKeyStaysInBrowserAddressBar(
                    for: step.action, in: app)))
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
        visualTarget: VisualTarget? = nil,
        elements: [UIElementSnapshot],
        limiter: ActionLimiter,
        checkerConcerns: [ConfirmationReason],
        returnKeyTargetTexts: [String],
        returnKeyStaysInBrowserAddressBar: Bool
    ) -> GateContext {
        GateContext(
            approvedStep: step,
            proposedAction: ProposedAction(
                kind: step.action.kind, targetApp: app.identity, targetElement: target,
                text: step.action.approvedText, key: Self.key(of: step.action),
                visualTarget: visualTarget),
            currentElements: elements,
            limitViolation: limiter.violation(at: .now),
            checkerConcerns: checkerConcerns,
            safetyState: SafetyState(
                isKillSwitchArmed: dependencies.killSwitch.isArmed,
                isWatchdogAlive: dependencies.isWatchdogAlive()),
            returnKeyTargetTexts: returnKeyTargetTexts,
            returnKeyStaysInBrowserAddressBar: returnKeyStaysInBrowserAddressBar)
    }

    /// Whether Return would land in a browser's own address bar. Only asked of browsers, so no
    /// other app's focused control is climbed.
    private func returnKeyStaysInBrowserAddressBar(for action: StepAction, in app: ResolvedApp)
        async -> Bool
    {
        guard Self.key(of: action) == .returnKey,
            WebBrowsers.isBrowser(bundleIdentifier: app.identity.bundleIdentifier)
        else {
            return false
        }
        return await dependencies.screenReader.focusedControlIsBrowserAddressBar(in: app)
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

    /// What a step acts on: a control read from the window with the checkers' concerns, or a
    /// point found by sight for a click whose control could not be read.
    enum ChosenTarget {
        case element(UIElementSnapshot, pickedBy: PickSource, concerns: [ConfirmationReason])
        case sight(VisualClick)
    }

    private func chooseTarget(
        for step: ScreenedStep, goal: String, snapshot: ScreenSnapshot,
        limiter: inout ActionLimiter, timings: inout StepTimings
    ) async throws -> ChosenTarget {
        try await stopIfNothingCanBePicked(for: step, in: snapshot)
        if snapshot.table.elements.isEmpty {
            try await auditControlsOffered(in: snapshot, for: step)
            return .sight(
                try await timings.measure("look") {
                    try await locateBySight(for: step, goal: goal, in: snapshot.app)
                })
        }
        var retryNote: String?
        // Picks rejected for not matching the plan; the model is not offered them again, since
        // at temperature 0 it would mostly repeat itself.
        var rejectedElements: [UIElementSnapshot] = []
        while true {
            let offeredElements = snapshot.table.elements.filter { !rejectedElements.contains($0) }
            if !rejectedElements.isEmpty,
                ElementRoles.candidates(in: offeredElements, for: step.action.kind).isEmpty
            {
                return try await noMatchingControl(
                    for: step, goal: goal, snapshot: snapshot,
                    reason: "every control was tried and none matches the plan", timings: &timings)
            }
            if let violation = limiter.violation(at: .now),
                violation
                    != .actionsTooClose(
                        minimumSeconds: currentPolicy.limits.minimumSecondsBetweenActions)
            {
                try await auditControlsOffered(in: snapshot, for: step)
                throw RunnerStop.blocked(.limitReached(violation), stepNumber: step.number)
            }
            let choice: TargetChoice
            let pickStart = ContinuousClock.now
            do {
                choice = try await dependencies.planner.pickTarget(
                    for: step.action, goal: goal, among: offeredElements,
                    appName: step.app?.displayName ?? "", windowTitle: snapshot.windowTitle,
                    retryNote: retryNote)
                timings.record("pick", ContinuousClock.now - pickStart)
            } catch .model(let modelError) {
                throw RunnerStop.failed(modelError.explanation)
            } catch {
                timings.record("pick", ContinuousClock.now - pickStart)
                limiter.recordModelError()
                retryNote = error.explanation
                try await audit(.modelError, error.explanation)
                continue
            }
            switch choice {
            case .blocked(let reason):
                return try await noMatchingControl(
                    for: step, goal: goal, snapshot: snapshot, reason: reason, timings: &timings)
            case .element(let element, let pickedBy):
                if let mismatch = planMismatchToRetry(element, for: step, in: snapshot) {
                    limiter.recordModelError()
                    rejectedElements.append(element)
                    retryNote = mismatch
                    try await audit(.modelError, mismatch)
                    continue
                }
                let concerns = try await timings.measure("check") {
                    try await checkerConcerns(
                        for: step, goal: goal, snapshot: snapshot, chosen: element,
                        pickedBy: pickedBy)
                }
                return .element(element, pickedBy: pickedBy, concerns: concerns)
            }
        }
    }

    /// No control fits the step: a click is looked for by sight; anything else stops.
    private func noMatchingControl(
        for step: ScreenedStep, goal: String, snapshot: ScreenSnapshot, reason: String,
        timings: inout StepTimings
    ) async throws -> ChosenTarget {
        try await audit(.modelError, "The AI found no matching control: \(reason)")
        try await auditControlsOffered(in: snapshot, for: step)
        guard step.action.kind == .click else {
            let description = step.action.targetDescription ?? step.action.summary
            throw RunnerStop.blocked(
                .unknownTarget(description: description), stepNumber: step.number)
        }
        return .sight(
            try await timings.measure("look") {
                try await locateBySight(for: step, goal: goal, in: snapshot.app)
            })
    }

    /// Stops before asking the model when it could only guess: the window gave no controls for
    /// a step that needs one (a click is looked for by sight instead), or the plan's control is
    /// there but greyed out and nothing enabled matches it.
    private func stopIfNothingCanBePicked(for step: ScreenedStep, in snapshot: ScreenSnapshot)
        async throws
    {
        let appName = snapshot.app.identity.displayName
        if snapshot.table.elements.isEmpty, step.action.kind != .click {
            try await auditControlsOffered(in: snapshot, for: step)
            throw RunnerStop.blocked(.noControlsRead(appName: appName), stepNumber: step.number)
        }
        guard let plannedTarget = step.action.targetDescription else {
            return
        }
        let matcher = PlanMatcher()
        let candidates = ElementRoles.candidates(
            in: snapshot.table.elements, for: step.action.kind)
        let enabledMatchExists = candidates.contains { element in
            matcher.elementMatchesPlan(targetDescription: plannedTarget, element: element)
        }
        if step.action.kind == .click, !enabledMatchExists,
            Self.describesWindowButton(plannedTarget)
        {
            throw RunnerStop.blocked(
                .windowButtonTarget(description: plannedTarget), stepNumber: step.number)
        }
        let disabledMatchExists = snapshot.table.disabledControlLabels.contains { label in
            matcher.textMatchesPlan(targetDescription: plannedTarget, text: label)
        }
        if !enabledMatchExists, disabledMatchExists {
            try await auditControlsOffered(in: snapshot, for: step)
            throw RunnerStop.blocked(
                .targetDisabled(description: plannedTarget, appName: appName),
                stepNumber: step.number)
        }
    }

    // MARK: - Sight

    /// Captures the window and asks the model where the step's control is. The point is only a
    /// proposal: the gate checks it and the person confirms it before anything is clicked.
    private func locateBySight(
        for step: ScreenedStep, goal: String, in app: ResolvedApp
    ) async throws -> VisualClick {
        let description = step.action.targetDescription ?? step.action.summary
        try await audit(
            .lookingBySight,
            "Looking at a screenshot of \(app.identity.displayName) for “\(SecretMasker.masked(description))”"
        )
        let capture: WindowCapture
        do {
            capture = try await dependencies.screenshotter.captureFrontWindow(of: app)
        } catch {
            throw RunnerStop.failed(error.explanation)
        }
        let location: VisualLocation
        do {
            location = try await dependencies.planner.locateByImage(
                for: step.action, goal: goal, screenshotPNG: capture.pngData)
        } catch .model(let modelError) {
            throw RunnerStop.failed(modelError.explanation)
        } catch {
            try await audit(.modelError, error.explanation)
            throw RunnerStop.blocked(
                .unknownTarget(description: description), stepNumber: step.number)
        }
        switch location {
        case .notFound(let reason):
            try await audit(
                .modelError, "The AI found nothing matching on screen either: \(reason)")
            throw RunnerStop.blocked(
                .unknownTarget(description: description), stepNumber: step.number)
        case .found(let gridX, let gridY, let foundDescription):
            return VisualClick(
                screenshotPNG: capture.pngData,
                target: VisualTarget(
                    windowFrame: capture.windowFrame, gridX: gridX, gridY: gridY,
                    description: foundDescription))
        }
    }

    /// Whether the window looks different after a click by sight: it is captured again and
    /// compared with the capture the point was found on. A failed capture counts as unchanged.
    private func windowImageChanged(in app: ResolvedApp, since visualClick: VisualClick)
        async throws -> Bool
    {
        do {
            let captureAfter = try await dependencies.screenshotter.captureFrontWindow(of: app)
            return captureAfter.pngData != visualClick.screenshotPNG
        } catch {
            try await audit(
                .screenReadFailed,
                "Could not capture \(app.identity.displayName) after clicking: \(error.explanation)"
            )
            return false
        }
    }

    /// The step as done, with the control it acted on and who chose that control, so the log
    /// shows what a vague target such as "first search result" really landed on.
    static func performedSummary(
        of action: StepAction, on element: UIElementSnapshot?, pickedBy: PickSource?
    ) -> String {
        guard let element, let pickedBy else {
            return action.summary
        }
        let controlDescription =
            "[\(element.number)] \(SecretMasker.masked(element.label)) (\(ElementRoles.displayName(of: element.role)))"
        return "\(action.summary) → \(controlDescription), \(pickedBy.logPhrase)"
    }

    static func clickedBySightSummary(_ visualTarget: VisualTarget, in app: ResolvedApp)
        -> String
    {
        "Clicked by sight at (\(visualTarget.gridX), \(visualTarget.gridY)) of \(VisualTarget.gridSize) in \(app.identity.displayName): “\(SecretMasker.masked(visualTarget.description))”"
    }

    /// Business rule: words naming a window's own title-bar buttons, which Glim never offers.
    private static let windowButtonWords: Set<String> = [
        "close", "minimize", "minimise", "zoom", "maximize", "maximise", "full", "screen",
        "fullscreen", "window",
    ]

    /// Whether `target` names only a title-bar button, such as "Close button" or "zoom".
    private static func describesWindowButton(_ target: String) -> Bool {
        let words = PlanMatcher.meaningfulWords(in: target)
        return !words.subtracting(["window"]).isEmpty && words.isSubset(of: windowButtonWords)
    }

    /// Records every control read from the window when no pick could be made, so the Activity
    /// Log shows whether the planned control was missing from what Glim read. List rows carry
    /// note and message titles, so secret-looking words are hidden before anything is logged.
    private func auditControlsOffered(in snapshot: ScreenSnapshot, for step: ScreenedStep)
        async throws
    {
        let controlDescriptions = snapshot.table.elements.map { element in
            "[\(element.number)] \(SecretMasker.masked(element.label)) (\(ElementRoles.displayName(of: element.role)))"
        }
        let windowName =
            snapshot.windowTitle.map { "“\(SecretMasker.masked($0))”" } ?? "the untitled window"
        let truncationNote =
            snapshot.table.wasTruncated
            ? " The window had more controls than the \(ScreenReadingLimits.maximumListedElements) listed."
            : ""
        let controlList =
            controlDescriptions.isEmpty ? "none" : controlDescriptions.joined(separator: ", ")
        let noControlsNote =
            controlDescriptions.isEmpty
            ? ChromiumKind.detect(
                bundleURL: snapshot.app.bundleURL,
                bundleIdentifier: snapshot.app.identity.bundleIdentifier)?
                .noControlsNote(appName: snapshot.app.identity.displayName) ?? "" : ""
        let leftOutLabels = snapshot.table.leftOutControlLabels.map(SecretMasker.masked)
        let leftOutNote =
            leftOutLabels.isEmpty
            ? "" : " Left out by the limit: \(leftOutLabels.joined(separator: ", "))."
        try await audit(
            .controlsOffered,
            "Controls read from \(windowName) for “\(step.action.summary)”: \(controlList).\(noControlsNote)\(truncationNote)\(leftOutNote)"
        )
    }

    /// When Glim asks only before danger, a pick that doesn't match the plan's wording is never
    /// clicked: it goes back to the model with this note, and repeated misses block the step.
    /// With the switch off, such a pick asks the person instead (see `SafetyGate`).
    private func planMismatchToRetry(
        _ element: UIElementSnapshot, for step: ScreenedStep, in snapshot: ScreenSnapshot
    ) -> String? {
        let isOnlyFieldToTypeInto =
            step.action.kind == .typeText
            && ElementRoles.candidates(in: snapshot.table.elements, for: .typeText).count == 1
        guard currentPolicy.asksOnlyBeforeDangerousSteps, !isOnlyFieldToTypeInto,
            let plannedTarget = step.action.targetDescription,
            !PlanMatcher().elementMatchesPlan(targetDescription: plannedTarget, element: element)
        else {
            return nil
        }
        return
            "“\(SecretMasker.masked(element.label))” doesn't match the plan's “\(plannedTarget)”. Pick the control that matches it, or report it blocked."
    }

    private func checkerConcerns(
        for step: ScreenedStep, goal: String, snapshot: ScreenSnapshot, chosen: UIElementSnapshot,
        pickedBy: PickSource
    ) async throws -> [ConfirmationReason] {
        let reviewRequest = TargetReviewRequest(
            goal: goal, step: step, windowTitle: snapshot.windowTitle,
            candidates: ElementRoles.candidates(in: snapshot.table.elements, for: step.action.kind),
            chosenElement: chosen, pickedBy: pickedBy)
        let result = await dependencies.checkerConsensus.review(reviewRequest)
        for outcome in result.outcomes {
            try await audit(.checkerVerdict, "\(outcome.checkerName): \(outcome.verdict)")
            if let saveExample = dependencies.layaExampleSaver,
                let example = LayaExample.make(
                    from: reviewRequest, outcome: outcome, id: UUID(), createdAt: Date())
            {
                await saveExample(example)
            }
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

    /// Reads the app's front window, waiting briefly for it: an app reopened with every window
    /// closed (Notes, for one) shows its window a moment later, and an app that was just opened
    /// can be too busy starting up to answer at first.
    private func snapshot(of app: ResolvedApp) async throws -> ScreenSnapshot {
        let deadline = ContinuousClock.now + timing.windowWaitTimeout
        while true {
            do {
                return try await dependencies.screenReader.snapshotFrontWindow(of: app)
            } catch let readingError {
                switch readingError {
                case .noWindow, .appNotResponding:
                    guard ContinuousClock.now < deadline else {
                        throw RunnerStop.failed(readingError.explanation)
                    }
                    try ensureArmed()
                    try await pause(for: timing.appLaunchPollInterval)
                case .accessibilityNotTrusted, .appNotRunning, .screenRecordingNotAllowed,
                    .captureFailed:
                    throw RunnerStop.failed(readingError.explanation)
                }
            }
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

    /// Whether the step visibly changed something. Opening or switching must bring the app to
    /// the front (macOS may decline an activation request); quitting must end it; window
    /// arrangements report their own success; in-app actions compare the window before and after.
    /// Glim never repeats an action automatically (a repeated click could send twice); unchanged
    /// steps count toward the no-change limit instead.
    ///
    /// - Returns: Whether the screen changed, and the window as read afterwards, which the next
    ///   step in the same app reuses.
    private func screenChanged(
        after step: ScreenedStep, in app: ResolvedApp, before: ScreenSnapshot?
    ) async throws -> (changed: Bool, screenAfter: ScreenSnapshot?) {
        let appName = app.identity.displayName
        switch step.action.kind {
        case .openApp, .switchApp:
            let isFront =
                dependencies.appResolver.frontmostApp()?.identity.bundleIdentifier
                == app.identity.bundleIdentifier
            return (isFront, nil)
        case .quitApp:
            return (dependencies.appResolver.resolveRunning(appNamed: appName) == nil, nil)
        case .moveWindow, .minimizeWindow, .restoreWindow, .speak:
            return (true, nil)
        case .click, .typeText, .pressKey, .scroll:
            break
        }
        guard let before,
            let runningApp = dependencies.appResolver.resolveRunning(appNamed: appName)
        else {
            return (true, nil)
        }
        var after: ScreenSnapshot
        do {
            after = try await dependencies.screenReader.snapshotFrontWindow(of: runningApp)
        } catch {
            try await audit(
                .screenReadFailed, "Could not re-read \(appName) after acting: \(error.explanation)"
            )
            return (false, nil)
        }
        if PageLoadSettle.waitsForPage(
            after: step.action, inAppWithBundleIdentifier: app.identity.bundleIdentifier)
        {
            after = try await settledPage(in: runningApp, firstRead: after, before: before)
        }
        if let typedText = step.action.approvedText,
            after.table.elements.contains(where: { $0.value?.contains(typedText) == true })
        {
            return (true, after)
        }
        return (after.table != before.table || after.windowTitle != before.windowTitle, after)
    }

    /// Reads the browser window again until its new page stops changing, so the next step picks
    /// from the loaded page rather than the one shown right after acting. When time runs out, or
    /// a read fails, the latest read is kept and the step goes on as before.
    private func settledPage(
        in app: ResolvedApp, firstRead: ScreenSnapshot, before: ScreenSnapshot
    ) async throws -> ScreenSnapshot {
        let deadline = ContinuousClock.now + timing.pageSettleTimeout
        var previousRead: ScreenSnapshot?
        var latestRead = firstRead
        while !PageLoadSettle.hasSettled(latestRead, previous: previousRead, before: before),
            ContinuousClock.now < deadline
        {
            try ensureArmed()
            try await pause(for: timing.pageSettlePollInterval)
            previousRead = latestRead
            do {
                latestRead = try await dependencies.screenReader.snapshotFrontWindow(of: app)
            } catch {
                try await audit(
                    .screenReadFailed,
                    "Could not re-read \(app.identity.displayName) while its page loaded: \(error.explanation)"
                )
                return latestRead
            }
        }
        return latestRead
    }

    private static func key(of action: StepAction) -> AllowedKey? {
        if case .pressKey(_, let key) = action {
            return key
        }
        return nil
    }
}
