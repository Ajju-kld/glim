import CoreGraphics
import Testing

@testable import GlimCore

struct OrbMoodTests {
    @Test func everyVisibleStatusHasAMood() {
        #expect(PillStatus.hidden.orbMood == nil)
        #expect(
            PillStatus.listening(transcript: "", level: 0.5).orbMood == .listening(level: 0.5))
        #expect(PillStatus.thinking.orbMood == .thinking)
        #expect(PillStatus.waitingForYou.orbMood == .waiting)
        #expect(
            PillStatus.acting(stepNumber: 1, totalSteps: 2, summary: "Open Notes").orbMood
                == .acting)
        #expect(PillStatus.done(message: "Done").orbMood == .done)
        #expect(PillStatus.stopped(reason: "Stopped").orbMood == .alert)
    }
}

struct OrbMotionTests {
    @Test func processingSpringsOutAndSettlesBackEachBeat() {
        let beatStart = OrbMotion.scale(for: .thinking, at: 0)
        let peak =
            (0..<100).map { step in
                OrbMotion.scale(
                    for: .thinking, at: OrbMotion.springBeatSeconds * Double(step) / 100)
            }.max() ?? 1
        let beatEnd = OrbMotion.scale(
            for: .thinking, at: OrbMotion.springBeatSeconds * 0.999)

        #expect(abs(beatStart - 1) < 0.001)
        #expect(peak > 1.05)
        #expect(abs(beatEnd - 1) < 0.02)
    }

    @Test func louderVoiceMakesABiggerOrb() {
        let quiet = OrbMotion.scale(for: .listening(level: 0), at: 0)
        let loud = OrbMotion.scale(for: .listening(level: 1), at: 0)

        #expect(loud > quiet)
        #expect(
            OrbMotion.ripple(for: .listening(level: 1))
                > OrbMotion.ripple(for: .listening(level: 0)))
    }

    @Test func doneOrbIsStill() {
        #expect(OrbMotion.scale(for: .done, at: 0.37) == 1)
    }

    @Test func processingSpinsFasterThanWaiting() {
        #expect(OrbMotion.spinSpeed(for: .thinking) > OrbMotion.spinSpeed(for: .waiting))
    }
}

struct LiquidOrbGeometryTests {
    @Test func calmOrbIsAPerfectCircle() {
        for step in 0..<24 {
            let angle = Double(step) / 24 * 2 * .pi
            #expect(LiquidOrbGeometry.edgeRadius(at: angle, time: 3.7, ripple: 0) == 1)
        }
    }

    @Test func rippleStaysInsideTheOrbAndMovesTheEdge() {
        let radii = (0..<72).map { step in
            LiquidOrbGeometry.edgeRadius(
                at: Double(step) / 72 * 2 * .pi, time: 1.3, ripple: 1)
        }

        #expect(radii.allSatisfy { $0 <= 1 && $0 >= 1 - LiquidOrbGeometry.maximumRippleDepth })
        #expect((radii.max() ?? 0) - (radii.min() ?? 0) > 0.03)
    }

    @Test func edgeIsClosedAndSmooth() {
        let start = LiquidOrbGeometry.edgeRadius(at: 0, time: 2, ripple: 0.8)
        let end = LiquidOrbGeometry.edgeRadius(at: 2 * .pi, time: 2, ripple: 0.8)

        #expect(abs(start - end) < 0.000_1)
    }

    @Test func meshCornersStayPutAndInnerPointsFlow() {
        let before = LiquidOrbGeometry.meshPoints(time: 0, flow: 1)
        let after = LiquidOrbGeometry.meshPoints(time: 0.8, flow: 1)

        #expect(before.count == 9)
        #expect(before[0] == SIMD2(0, 0) && before[2] == SIMD2(1, 0))
        #expect(before[6] == SIMD2(0, 1) && before[8] == SIMD2(1, 1))
        #expect(before[4] != after[4])
        #expect(after.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }
}

struct PillLayoutTests {
    let notch = CGSize(width: 185, height: 32)

    @Test func hiddenPillTucksIntoTheNotch() {
        #expect(PillLayout.size(for: .hidden, notchSize: notch) == notch)
    }

    @Test func listeningGrowsOutOfTheNotchAndWidensWithWords() {
        let silent = PillLayout.size(for: .listening(transcript: "", level: 0), notchSize: notch)
        let speaking = PillLayout.size(
            for: .listening(transcript: "open notes", level: 0.5), notchSize: notch)

        #expect(silent.width > notch.width)
        #expect(silent.height == notch.height + PillLayout.contentHeight)
        #expect(speaking.width > silent.width)
    }

    @Test func workingPillsUseTheFullWidth() {
        let acting = PillLayout.size(
            for: .acting(stepNumber: 1, totalSteps: 3, summary: "Open Notes"), notchSize: notch)

        #expect(acting.width == PillLayout.expandedWidth)
    }

    @Test func largestSizeFitsEveryState() {
        let largest = PillLayout.largestSize(notchSize: notch)
        let statuses: [PillStatus] = [
            .listening(transcript: "hi", level: 1), .thinking, .waitingForYou,
            .acting(stepNumber: 1, totalSteps: 1, summary: "x"), .done(message: "Done"),
            .stopped(reason: "No"),
        ]

        for status in statuses {
            let size = PillLayout.size(for: status, notchSize: notch)
            #expect(size.width <= largest.width && size.height <= largest.height)
        }
    }
}

struct PillStopButtonTests {
    @Test(arguments: [
        (PillStatus.thinking, true), (.waitingForYou, true),
        (.acting(stepNumber: 1, totalSteps: 1, summary: "x"), true),
        (.listening(transcript: "", level: 0), false), (.done(message: "Done"), false),
        (.stopped(reason: "No"), false), (.hidden, false),
    ])
    func stopIsOfferedOnlyWhileGlimWorks(status: PillStatus, offersStop: Bool) {
        #expect(status.offersStop == offersStop)
    }
}
