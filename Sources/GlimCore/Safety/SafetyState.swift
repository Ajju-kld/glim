/// The two switches that must both be on before any action runs.
public struct SafetyState: Sendable, Equatable {
    /// Whether the kill switch is armed (not tripped).
    public let isKillSwitchArmed: Bool
    /// Whether the watchdog that owns ⌃⌥⌘K is running.
    public let isWatchdogAlive: Bool

    /// Creates a safety state.
    public init(isKillSwitchArmed: Bool, isWatchdogAlive: Bool) {
        self.isKillSwitchArmed = isKillSwitchArmed
        self.isWatchdogAlive = isWatchdogAlive
    }
}
