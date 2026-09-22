import Testing

@testable import GlimCore

struct ListeningSessionGateTests {
    @Test func normalStartThenStop() {
        var gate = ListeningSessionGate()
        let session = gate.beginStarting()
        let shouldContinue = gate.shouldContinueStarting(session)
        let didFinish = gate.finishStarting(session)
        let stopDisposition = gate.requestStop()

        #expect(shouldContinue)
        #expect(didFinish)
        #expect(stopDisposition == .stopListening)
        #expect(gate.phase == .idle)
    }

    @Test func releaseDuringStartupCancelsTheStart() {
        var gate = ListeningSessionGate()
        let session = gate.beginStarting()
        let stopDisposition = gate.requestStop()
        let shouldContinue = gate.shouldContinueStarting(session)
        let didFinish = gate.finishStarting(session)

        #expect(stopDisposition == .cancelStart)
        #expect(!shouldContinue)
        #expect(!didFinish)
        #expect(gate.phase == .idle)
    }

    @Test func aNewerStartSupersedesAnOlderOne() {
        var gate = ListeningSessionGate()
        let firstSession = gate.beginStarting()
        let secondSession = gate.beginStarting()

        #expect(!gate.shouldContinueStarting(firstSession))
        #expect(gate.shouldContinueStarting(secondSession))
    }

    @Test func stopWithNothingRunningIsReported() {
        var gate = ListeningSessionGate()
        let stopDisposition = gate.requestStop()

        #expect(stopDisposition == .nothingToStop)
    }

    @Test func resetCancelsAnyStart() {
        var gate = ListeningSessionGate()
        let session = gate.beginStarting()
        gate.reset()

        #expect(!gate.shouldContinueStarting(session))
    }
}
