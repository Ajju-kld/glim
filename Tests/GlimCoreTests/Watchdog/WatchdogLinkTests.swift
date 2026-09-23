import Foundation
import Synchronization
import Testing

@testable import GlimCore

final class SignalCounter: Sendable {
    private let count = Mutex(0)

    var value: Int {
        count.withLock { $0 }
    }

    func increment() {
        count.withLock { $0 += 1 }
    }
}

struct WatchdogLinkTests {
    /// A unique prefix per test, so parallel tests and a running Glim never hear each other.
    let link = WatchdogLink(namePrefix: "dev.straxs.GlimTests.\(UUID().uuidString)")

    func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func signalNamesAreDistinct() {
        let names = WatchdogSignal.allCases.map(link.notificationName(for:))

        #expect(Set(names).count == WatchdogSignal.allCases.count)
    }

    @Test func postedSignalReachesTheObserver() async throws {
        let counter = SignalCounter()
        let observation = try link.observe(.stopRequested) { counter.increment() }

        link.post(.stopRequested)
        try await waitUntil { counter.value > 0 }
        link.cancel(observation)

        #expect(counter.value == 1)
    }

    @Test func stopRequestTripsTheSwitchAndIsAcknowledged() async throws {
        let killSwitch = KillSwitch()
        let acknowledgements = SignalCounter()
        let acknowledgementObservation = try link.observe(.stopAcknowledged) {
            acknowledgements.increment()
        }
        let responder = try WatchdogStopResponder(link: link, killSwitch: killSwitch)

        link.post(.stopRequested)
        try await waitUntil { acknowledgements.value > 0 }
        responder.stop()
        link.cancel(acknowledgementObservation)

        #expect(killSwitch.tripReason == .killHotkey)
        #expect(acknowledgements.value == 1)
    }

    @Test func processLivenessIsDetected() {
        #expect(WatchdogLink.isProcessAlive(getpid()))
        #expect(!WatchdogLink.isProcessAlive(-1))
    }
}
