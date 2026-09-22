import Foundation
import Synchronization
import Testing

@testable import GlimCore

/// Reports how long ago "human input" happened, as scripted by the test.
final class ScriptedInputClock: HumanInputClock {
    private let lastInputAt = Mutex(Date.distantPast)

    func simulateHumanInput() {
        lastInputAt.withLock { $0 = Date() }
    }

    func secondsSinceLastHumanInput() -> TimeInterval {
        lastInputAt.withLock { Date().timeIntervalSince($0) }
    }
}

struct TakeoverMonitorTests {
    let quickTiming = TakeoverMonitor.Timing(
        settleDelay: .milliseconds(30), pollInterval: .milliseconds(5), graceSeconds: 0.01)

    @Test func inputAfterWatchingStartedMeansTakeover() {
        #expect(TakeoverMonitor.humanTookOver(secondsSinceLastInput: 0.2, secondsWatching: 2))
    }

    @Test func inputBeforeWatchingStartedIsIgnored() {
        #expect(!TakeoverMonitor.humanTookOver(secondsSinceLastInput: 5, secondsWatching: 2))
    }

    @Test func humanInputWhileActingTripsTheKillSwitch() async throws {
        let killSwitch = KillSwitch()
        let inputClock = ScriptedInputClock()
        let monitor = TakeoverMonitor(
            killSwitch: killSwitch, inputClock: inputClock, timing: quickTiming)

        let watching = Task { await monitor.watchUntilCancelled() }
        try await Task.sleep(for: .milliseconds(80))
        inputClock.simulateHumanInput()
        try await Task.sleep(for: .milliseconds(80))
        watching.cancel()
        await watching.value

        #expect(killSwitch.tripReason == .humanTookOver)
    }

    @Test func inputDuringTheSettleDelayIsIgnored() async throws {
        let killSwitch = KillSwitch()
        let inputClock = ScriptedInputClock()
        let slowSettle = TakeoverMonitor.Timing(
            settleDelay: .milliseconds(200), pollInterval: .milliseconds(5), graceSeconds: 0.01)
        let monitor = TakeoverMonitor(
            killSwitch: killSwitch, inputClock: inputClock, timing: slowSettle)

        let watching = Task { await monitor.watchUntilCancelled() }
        try await Task.sleep(for: .milliseconds(20))
        inputClock.simulateHumanInput()
        try await Task.sleep(for: .milliseconds(100))
        watching.cancel()
        await watching.value

        #expect(killSwitch.isArmed)
    }

    @Test func quietHandsLeaveTheSwitchArmed() async throws {
        let killSwitch = KillSwitch()
        let monitor = TakeoverMonitor(
            killSwitch: killSwitch, inputClock: ScriptedInputClock(), timing: quickTiming)

        let watching = Task { await monitor.watchUntilCancelled() }
        try await Task.sleep(for: .milliseconds(120))
        watching.cancel()
        await watching.value

        #expect(killSwitch.isArmed)
    }
}
