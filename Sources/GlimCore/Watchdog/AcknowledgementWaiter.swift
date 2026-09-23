import Synchronization

/// Waits for Glim's "stopped" acknowledgement after the watchdog asks it to stop.
///
/// Arm it *before* posting the stop request, so an instant acknowledgement can't be missed;
/// arming also clears any stale acknowledgement from an earlier stop.
public final class AcknowledgementWaiter: Sendable {
    /// Shared between the waiter and its notification handler.
    private final class State: Sendable {
        struct Flags {
            var isArmed = false
            var hasAcknowledged = false
        }

        let flags = Mutex(Flags())
    }

    /// Tunable: how often the waiter checks for the acknowledgement.
    private static let pollInterval = Duration.milliseconds(10)

    private let link: WatchdogLink
    private let state = State()
    private let observation: WatchdogLink.Observation

    /// Starts listening for acknowledgements.
    public init(link: WatchdogLink) throws(WatchdogLink.LinkError) {
        self.link = link
        let sharedState = state
        observation = try link.observe(.stopAcknowledged) {
            sharedState.flags.withLock { flags in
                if flags.isArmed {
                    flags.hasAcknowledged = true
                }
            }
        }
    }

    /// Clears old acknowledgements and starts accepting new ones.
    public func arm() {
        state.flags.withLock { flags in
            flags.isArmed = true
            flags.hasAcknowledged = false
        }
    }

    /// Waits up to `timeout` for an acknowledgement received since ``arm()``.
    public func waitForAcknowledgement(within timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if hasAcknowledged {
                return true
            }
            do {
                try await Task.sleep(for: Self.pollInterval)
            } catch {
                return hasAcknowledged
            }
        }
        return hasAcknowledged
    }

    /// Stops listening.
    public func stop() {
        link.cancel(observation)
    }

    private var hasAcknowledged: Bool {
        state.flags.withLock { $0.hasAcknowledged }
    }
}
