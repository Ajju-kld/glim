/// Pauses the runner uses while acting.
public struct RunnerTiming: Sendable {
    /// Tunable: lets the app update its window before Glim checks what changed.
    public let settleAfterAction: Duration
    /// Tunable: how long an opening app may take to appear.
    public let appLaunchTimeout: Duration
    /// Tunable: how often Glim looks for the opening app or its window.
    public let appLaunchPollInterval: Duration
    /// Tunable: how long a step waits for its app to show a window, for example after Notes is
    /// reopened with every window closed.
    public let windowWaitTimeout: Duration
    /// Tunable: how long Glim waits for a web page to finish loading after a click or Return in
    /// a browser, before the next step reads it. A slow page is read as it is when time runs out.
    public let pageSettleTimeout: Duration
    /// Tunable: how often the browser window is read while its page loads.
    public let pageSettlePollInterval: Duration

    /// The live timing.
    public static let standard = RunnerTiming(
        settleAfterAction: .milliseconds(250), appLaunchTimeout: .seconds(8),
        appLaunchPollInterval: .milliseconds(100), windowWaitTimeout: .seconds(3),
        pageSettleTimeout: .seconds(5), pageSettlePollInterval: .milliseconds(300))

    /// Creates a timing.
    public init(
        settleAfterAction: Duration, appLaunchTimeout: Duration, appLaunchPollInterval: Duration,
        windowWaitTimeout: Duration, pageSettleTimeout: Duration = .seconds(5),
        pageSettlePollInterval: Duration = .milliseconds(300)
    ) {
        self.settleAfterAction = settleAfterAction
        self.appLaunchTimeout = appLaunchTimeout
        self.appLaunchPollInterval = appLaunchPollInterval
        self.windowWaitTimeout = windowWaitTimeout
        self.pageSettleTimeout = pageSettleTimeout
        self.pageSettlePollInterval = pageSettlePollInterval
    }
}
