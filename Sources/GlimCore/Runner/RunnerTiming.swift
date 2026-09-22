/// Pauses the runner uses while acting.
public struct RunnerTiming: Sendable {
    /// Tunable: lets the app update its window before Glim checks what changed.
    public let settleAfterAction: Duration
    /// Tunable: how long an opening app may take to appear.
    public let appLaunchTimeout: Duration
    /// Tunable: how often Glim looks for the opening app.
    public let appLaunchPollInterval: Duration

    /// The live timing.
    public static let standard = RunnerTiming(
        settleAfterAction: .milliseconds(400), appLaunchTimeout: .seconds(8),
        appLaunchPollInterval: .milliseconds(250))

    /// Creates a timing.
    public init(
        settleAfterAction: Duration, appLaunchTimeout: Duration, appLaunchPollInterval: Duration
    ) {
        self.settleAfterAction = settleAfterAction
        self.appLaunchTimeout = appLaunchTimeout
        self.appLaunchPollInterval = appLaunchPollInterval
    }
}
