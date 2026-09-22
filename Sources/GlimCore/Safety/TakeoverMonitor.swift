import Foundation

/// Hands control back to the person the moment they touch the keyboard, mouse or trackpad
/// while Glim is acting (B-Q5), by tripping the kill switch.
public struct TakeoverMonitor: Sendable {
    /// How the monitor waits and polls.
    public struct Timing: Sendable {
        /// Tunable: input right after clicking Approve (a hand still moving the mouse) is
        /// ignored for this long.
        public let settleDelay: Duration
        /// Tunable: how often the input clock is read.
        public let pollInterval: Duration
        /// Tunable: slack for timing jitter between the two clocks.
        public let graceSeconds: TimeInterval

        /// The live timing.
        public static let standard = Timing(
            settleDelay: .seconds(1), pollInterval: .milliseconds(50), graceSeconds: 0.05)

        /// Creates a timing.
        public init(settleDelay: Duration, pollInterval: Duration, graceSeconds: TimeInterval) {
            self.settleDelay = settleDelay
            self.pollInterval = pollInterval
            self.graceSeconds = graceSeconds
        }
    }

    private let killSwitch: KillSwitch
    private let inputClock: any HumanInputClock
    private let timing: Timing

    /// Creates a monitor that trips `killSwitch` on human input.
    public init(killSwitch: KillSwitch, inputClock: any HumanInputClock, timing: Timing = .standard)
    {
        self.killSwitch = killSwitch
        self.inputClock = inputClock
        self.timing = timing
    }

    /// Watches until the task is cancelled or a person takes over. The runner starts this when
    /// acting begins and cancels it whenever a panel waits for the person.
    ///
    /// - Parameter startInstant: When watching was requested. Measuring from here — not from
    ///   when this task first gets to run — means input in a scheduling gap is never missed.
    public func watchUntilCancelled(from startInstant: ContinuousClock.Instant) async {
        let watchingStartedAt = startInstant + timing.settleDelay
        do {
            try await Task.sleep(until: watchingStartedAt, clock: .continuous)
        } catch {
            return
        }
        while !Task.isCancelled, killSwitch.isArmed {
            let secondsWatching = Self.seconds(in: ContinuousClock.now - watchingStartedAt)
            let secondsSinceInput = inputClock.secondsSinceLastHumanInput() + timing.graceSeconds
            if Self.humanTookOver(
                secondsSinceLastInput: secondsSinceInput, secondsWatching: secondsWatching)
            {
                killSwitch.trip(.humanTookOver)
                return
            }
            do {
                try await Task.sleep(for: timing.pollInterval)
            } catch {
                return
            }
        }
    }

    /// Input happened after watching started exactly when it is more recent than the start.
    static func humanTookOver(secondsSinceLastInput: TimeInterval, secondsWatching: TimeInterval)
        -> Bool
    {
        secondsSinceLastInput < secondsWatching
    }

    private static func seconds(in duration: Duration) -> TimeInterval {
        let components = duration.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}
