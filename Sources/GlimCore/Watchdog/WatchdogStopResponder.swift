/// Glim's side of the ⌃⌥⌘K handshake: on the watchdog's stop request, trip the kill switch and
/// acknowledge, so the watchdog doesn't have to force-quit Glim.
public final class WatchdogStopResponder: Sendable {
    private let link: WatchdogLink
    private let observation: WatchdogLink.Observation

    /// Starts listening for stop requests.
    public init(link: WatchdogLink, killSwitch: KillSwitch) throws(WatchdogLink.LinkError) {
        self.link = link
        observation = try link.observe(.stopRequested) { [link] in
            killSwitch.trip(.killHotkey)
            link.post(.stopAcknowledged)
        }
    }

    /// Stops listening.
    public func stop() {
        link.cancel(observation)
    }
}
