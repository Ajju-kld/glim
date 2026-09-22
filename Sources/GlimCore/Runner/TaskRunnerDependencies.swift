/// Everything the runner uses, injected so tests can replace the real Mac with fakes.
public struct TaskRunnerDependencies: Sendable {
    let planner: Planner
    let screenReader: any ScreenReading
    let screenshotter: any ScreenshotCapturing
    let appResolver: AppResolver
    let checkerConsensus: CheckerConsensus
    let executor: any ActionPerforming
    let decisions: any PersonDecisions
    let narrator: any Narrating
    let killSwitch: KillSwitch
    let auditLog: AuditLog
    let takeoverMonitor: TakeoverMonitor?
    let safetyPolicy: SafetyPolicy
    let isWatchdogAlive: @Sendable () -> Bool

    /// Collects the runner's dependencies.
    public init(
        planner: Planner,
        screenReader: any ScreenReading,
        screenshotter: any ScreenshotCapturing,
        appResolver: AppResolver,
        checkerConsensus: CheckerConsensus,
        executor: any ActionPerforming,
        decisions: any PersonDecisions,
        narrator: any Narrating,
        killSwitch: KillSwitch,
        auditLog: AuditLog,
        takeoverMonitor: TakeoverMonitor?,
        safetyPolicy: SafetyPolicy,
        isWatchdogAlive: @escaping @Sendable () -> Bool
    ) {
        self.planner = planner
        self.screenReader = screenReader
        self.screenshotter = screenshotter
        self.appResolver = appResolver
        self.checkerConsensus = checkerConsensus
        self.executor = executor
        self.decisions = decisions
        self.narrator = narrator
        self.killSwitch = killSwitch
        self.auditLog = auditLog
        self.takeoverMonitor = takeoverMonitor
        self.safetyPolicy = safetyPolicy
        self.isWatchdogAlive = isWatchdogAlive
    }
}
