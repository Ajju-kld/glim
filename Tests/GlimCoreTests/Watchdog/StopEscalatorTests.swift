import Synchronization
import Testing

@testable import GlimCore

final class EscalationRecorder: Sendable {
    private let recordedSteps = Mutex<[String]>([])

    var steps: [String] {
        recordedSteps.withLock { $0 }
    }

    func record(_ step: String) {
        recordedSteps.withLock { $0.append(step) }
    }
}

struct StopEscalatorTests {
    @Test func acknowledgedStopNeedsNoForce() async {
        let recorder = EscalationRecorder()
        let escalator = StopEscalator(acknowledgementTimeout: .milliseconds(500))

        let result = await escalator.stop(
            requestStop: { recorder.record("request") },
            waitForAcknowledgement: { _ in true },
            forceStop: { recorder.record("force") })

        #expect(result == .acknowledged)
        #expect(recorder.steps == ["request"])
    }

    @Test func silentGlimIsForceStopped() async {
        let recorder = EscalationRecorder()
        let escalator = StopEscalator(acknowledgementTimeout: .milliseconds(500))

        let result = await escalator.stop(
            requestStop: { recorder.record("request") },
            waitForAcknowledgement: { timeout in
                recorder.record("wait \(timeout)")
                return false
            },
            forceStop: { recorder.record("force") })

        #expect(result == .forceStopped)
        #expect(recorder.steps == ["request", "wait 0.5 seconds", "force"])
    }

    @Test func standardTimeoutIsHalfASecond() {
        #expect(StopEscalator.standardAcknowledgementTimeout == .milliseconds(500))
    }
}
