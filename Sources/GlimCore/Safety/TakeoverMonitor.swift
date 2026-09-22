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
    public func watchUntilCancelled() async {
        do {
            try await Task.sleep(for: timing.settleDelay)
        } catch {
            return
        }
        let watchingStartedAt = ContinuousClock.now
        while !Task.isCancelled, killSwitch.isArmed {
            do {
                try await Task.sleep(for: timing.pollInterval)
            } catch {
                return
            }
            let secondsWatching = Self.seconds(in: ContinuousClock.now - watchingStartedAt)
            let secondsSinceInput = inputClock.secondsSinceLastHumanInput() + timing.graceSeconds
            if Self.humanTookOver(
                secondsSinceLastInput: secondsSinceInput, secondsWatching: secondsWatching)
            {
                killSwitch.trip(.humanTookOver)
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
