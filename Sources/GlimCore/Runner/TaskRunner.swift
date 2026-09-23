import Foundation

/// Carries one spoken request from transcript to outcome.
///
/// Questions are answered by reading, never by acting. Tasks are planned, screened, shown for
/// approval, then run step by step through the safety gate (spec §8, §10). Every stage is
/// written to the audit log; if the log can't be written, the task stops (fail closed).
public struct TaskRunner: Sendable {
    let dependencies: TaskRunnerDependencies
    let timing: RunnerTiming
    /// The policy when this runner was created; a runner serves one request.
    private let startingPolicy: SafetyPolicy

    /// Creates a runner for one request.
    public init(dependencies: TaskRunnerDependencies, timing: RunnerTiming = .standard) {
        self.dependencies = dependencies
        self.timing = timing
        self.startingPolicy = dependencies.safetyPolicyProvider()
    }

    /// The policy in force right now: the starting policy combined strictly with the current
    /// settings, so a tightening applies at once and a loosening never reaches a running task.
    var currentPolicy: SafetyPolicy {
        startingPolicy.combinedStrictly(with: dependencies.safetyPolicyProvider())
    }

    /// Runs one request and reports progress through `onEvent`.
    public func run(
        transcript: String, onEvent: @escaping @Sendable (TaskEvent) -> Void
    ) async -> TaskOutcome {
        var outcome = await outcome(for: transcript, onEvent: onEvent)
        // Stopping cancels in-flight requests; their errors ("Ollama isn't running") are
        // side effects of the stop, not the real reason.
        if case .failed = outcome, let tripReason = dependencies.killSwitch.tripReason {
            outcome = .stopped(tripReason)
        }
        do {
            try await audit(.taskFinished, "Task ended: \(outcome)")
        } catch {
            // The outcome already stands; the audit failure is reported instead of hidden.
            onEvent(.finished(.failed("The audit log could not be written.")))
            return .failed("The audit log could not be written.")
        }
        onEvent(.finished(outcome))
        return outcome
    }

    private func outcome(
        for transcript: String, onEvent: @escaping @Sendable (TaskEvent) -> Void
    ) async -> TaskOutcome {
        let goal = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else {
            return .failed("Didn't catch that.")
        }
        if SpokenCommandMatcher.isStopCommand(goal, whileTaskIsRunning: false) {
            dependencies.killSwitch.trip(.spokenStop)
            return .stopped(.spokenStop)
        }
        do {
            try await audit(.transcript, goal)
            onEvent(.thinking)
            let frontApp = dependencies.appResolver.frontmostApp()
            let frontSnapshot = try await readableSnapshot(of: frontApp)
            let context = PlanningContext(
                goal: goal,
                frontAppName: frontApp?.identity.displayName,
                windowTitle: frontSnapshot?.windowTitle,
                elementLabels: frontSnapshot?.table.elements.map(\.label) ?? [],
                installedAppNames: dependencies.appResolver.installedAppNames(),
                runningAppNames: dependencies.appResolver.runningAppNames(),
                limits: currentPolicy.limits)
            switch try await plannerResult(for: context) {
            case .question:
                return try await answerQuestion(goal, frontApp: frontApp, snapshot: frontSnapshot)
            case .task(let plan):
                return try await runTask(plan, onEvent: onEvent)
            }
        } catch let stop as RunnerStop {
            return stop.outcome
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Questions

    private func answerQuestion(
        _ question: String, frontApp: ResolvedApp?, snapshot: ScreenSnapshot?
    ) async throws -> TaskOutcome {
        guard let frontApp, canRead(frontApp) else {
            let refusal = "I don't read that app. It's on Glim's never-touch list."
            await dependencies.narrator.say(refusal)
            return .answered(refusal)
        }
        var screenshot: Data?
        if snapshot?.table.needsScreenshotToAnswerQuestions ?? true {
            do {
                screenshot = try await dependencies.screenshotter.capturePNG(of: frontApp)
            } catch {
                guard snapshot != nil else {
                    throw RunnerStop.failed(error.explanation)
                }
                try await audit(
                    .screenReadFailed,
                    "Screenshot failed; answering from text: \(error.explanation)")
            }
        }
        let answer: String
        do {
            answer = try await dependencies.planner.answerQuestion(
                question, screenText: snapshot?.table.readableText, screenshotPNG: screenshot)
        } catch {
            throw RunnerStop.failed(error.explanation)
        }
        try await audit(.answerGiven, answer)
        await dependencies.narrator.say(answer)
        return .answered(answer)
    }

    // MARK: - Tasks

    private func runTask(
        _ plan: Plan, onEvent: @escaping @Sendable (TaskEvent) -> Void
    ) async throws -> TaskOutcome {
        let screener = PlanScreener(policy: currentPolicy)
        let screening = screener.screen(plan) { appName in
            dependencies.appResolver.resolve(appNamed: appName)?.identity
        }
        let screenedPlan: ScreenedPlan
        switch screening {
        case .rejected(let violation, let stepNumber):
            try await audit(.planRejected, violation.explanation)
            throw RunnerStop.blocked(violation, stepNumber: stepNumber)
        case .readyForApproval(let readyPlan):
            screenedPlan = readyPlan
        }
        try await audit(
            .planProposed, screenedPlan.steps.map(\.action.summary).joined(separator: " → "))
        if LowRiskPlanRule.startsWithoutApproval(screenedPlan, policy: currentPolicy) {
            try await audit(.planApproved, "Started without asking: every step is low-risk.")
        } else {
            onEvent(.awaitingPlanApproval(screenedPlan))
            guard await dependencies.decisions.approvePlan(screenedPlan) else {
                try await audit(.planCancelled, "The person cancelled the plan.")
                throw RunnerStop.cancelled
            }
            try await audit(.planApproved, "The person approved the plan.")
        }

        let takeoverSupervisor = TakeoverSupervisor(monitor: dependencies.takeoverMonitor)
        takeoverSupervisor.start()
        defer { takeoverSupervisor.stop() }
        var limiter = ActionLimiter(limits: currentPolicy.limits, taskStartedAt: .now)
        for step in screenedPlan.steps {
            try await runStep(
                step, of: screenedPlan, limiter: &limiter, takeoverSupervisor: takeoverSupervisor,
                onEvent: onEvent)
        }
        await dependencies.narrator.say("Done")
        return .completed
    }

    // MARK: - Shared helpers

    private func plannerResult(for context: PlanningContext) async throws -> PlannerResult {
        do {
            return try await dependencies.planner.makePlan(for: context)
        } catch {
            try await audit(.modelError, error.explanation)
            throw RunnerStop.failed(error.explanation)
        }
    }

    /// Reads the front window for planning, unless the app is never-touch or has no window.
    private func readableSnapshot(of app: ResolvedApp?) async throws -> ScreenSnapshot? {
        guard let app, canRead(app) else {
            return nil
        }
        do {
            return try await dependencies.screenReader.snapshotFrontWindow(of: app)
        } catch .accessibilityNotTrusted {
            throw RunnerStop.failed(ScreenReadingError.accessibilityNotTrusted.explanation)
        } catch {
            try await audit(
                .screenReadFailed, "Planning without the front window: \(error.explanation)")
            return nil
        }
    }

    func canRead(_ app: ResolvedApp) -> Bool {
        currentPolicy.appTrust.tier(for: app.identity) != .neverTouch
    }

    func ensureArmed() throws {
        guard dependencies.killSwitch.isArmed else {
            throw RunnerStop.stopped(dependencies.killSwitch.tripReason ?? .stopButton)
        }
        guard !Task.isCancelled else {
            throw RunnerStop.stopped(dependencies.killSwitch.tripReason ?? .stopButton)
        }
    }

    func audit(_ kind: AuditEventKind, _ summary: String, details: [String: String] = [:])
        async throws
    {
        do {
            try await dependencies.auditLog.append(kind, summary: summary, details: details)
        } catch {
            throw RunnerStop.failed(
                "The audit log could not be written: \(error.localizedDescription)")
        }
    }

    func pause(for duration: Duration) async throws {
        guard duration > .zero else {
            return
        }
        do {
            try await Task.sleep(for: duration)
        } catch {
            throw RunnerStop.stopped(dependencies.killSwitch.tripReason ?? .stopButton)
        }
    }
}
