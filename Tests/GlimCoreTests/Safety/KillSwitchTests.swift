import Synchronization
import Testing

@testable import GlimCore

final class TripRecorder: Sendable {
    private let recordedReasons = Mutex<[TripReason]>([])

    var reasons: [TripReason] {
        recordedReasons.withLock { $0 }
    }

    func record(_ reason: TripReason) {
        recordedReasons.withLock { $0.append(reason) }
    }
}

struct KillSwitchTests {
    @Test func startsArmed() {
        let killSwitch = KillSwitch()

        #expect(killSwitch.isArmed)
        #expect(killSwitch.tripReason == nil)
    }

    @Test func tripStopsAndRemembersTheReason() {
        let killSwitch = KillSwitch()

        #expect(killSwitch.trip(.killHotkey))
        #expect(!killSwitch.isArmed)
        #expect(killSwitch.tripReason == .killHotkey)
    }

    @Test func secondTripKeepsTheFirstReason() {
        let killSwitch = KillSwitch()
        killSwitch.trip(.humanTookOver)

        #expect(!killSwitch.trip(.stopButton))
        #expect(killSwitch.tripReason == .humanTookOver)
    }

    @Test func handlersRunOnceWithTheReason() {
        let killSwitch = KillSwitch()
        let recorder = TripRecorder()
        _ = killSwitch.addTripHandler { reason in recorder.record(reason) }

        killSwitch.trip(.spokenStop)
        killSwitch.trip(.stopButton)

        #expect(recorder.reasons == [.spokenStop])
    }

    @Test func removedHandlerDoesNotRun() {
        let killSwitch = KillSwitch()
        let recorder = TripRecorder()
        let token = killSwitch.addTripHandler { reason in recorder.record(reason) }
        killSwitch.removeTripHandler(token)

        killSwitch.trip(.stopButton)

        #expect(recorder.reasons.isEmpty)
    }

    @Test func handlerCanReadTheSwitchWithoutDeadlocking() {
        let killSwitch = KillSwitch()
        let recorder = TripRecorder()
        _ = killSwitch.addTripHandler { _ in
            if let reason = killSwitch.tripReason {
                recorder.record(reason)
            }
        }

        killSwitch.trip(.panelCancelled)

        #expect(recorder.reasons == [.panelCancelled])
    }

    @Test func rearmAllowsActionsAgain() {
        let killSwitch = KillSwitch()
        killSwitch.trip(.stopButton)

        killSwitch.rearm()

        #expect(killSwitch.isArmed)
        #expect(killSwitch.tripReason == nil)
    }

    @Test func ensureArmedThrowsAfterATrip() {
        let killSwitch = KillSwitch()
        killSwitch.trip(.killHotkey)

        #expect(throws: GuardViolation.killSwitchTripped) {
            try killSwitch.ensureArmed()
        }
    }

    @Test func concurrentTripsTripExactlyOnce() async {
        let killSwitch = KillSwitch()
        let competingTripCount = 100

        let successfulTrips = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<competingTripCount {
                group.addTask { killSwitch.trip(.stopButton) }
            }
            var tripCount = 0
            for await didTrip in group where didTrip {
                tripCount += 1
            }
            return tripCount
        }

        #expect(successfulTrips == 1)
    }
}
