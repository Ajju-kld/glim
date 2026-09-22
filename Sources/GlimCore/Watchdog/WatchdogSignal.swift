/// Signals exchanged between Glim and its kill-switch watchdog.
public enum WatchdogSignal: String, Sendable, CaseIterable {
    /// The watchdog saw ⌃⌥⌘K and asks Glim to stop.
    case stopRequested = "stop"
    /// Glim stopped; without this within half a second the watchdog force-quits Glim.
    case stopAcknowledged = "stopped"
    /// The watchdog registered ⌃⌥⌘K and is watching.
    case watchdogReady = "watchdog.ready"
    /// The watchdog could not register ⌃⌥⌘K; Glim turns action mode off.
    case hotkeyFailed = "watchdog.hotkeyFailed"
}
