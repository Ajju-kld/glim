import Foundation
import Testing

@testable import GlimCore

/// A click step whose control Glim can't read is looked for on a screenshot, and every such
/// click asks the person first (design: docs/specs/2026-09-23-see-and-click-design.md).
extension TaskRunnerTests {
    static let clickPlayPlan =
        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Play"}]}"#
    static let playFoundBySight = #"{"description":"Play button","found":true,"x":480,"y":910}"#

    @Test func clickInAWindowWithNoControlsIsFoundBySightAndAsks() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickPlayPlan, Self.playFoundBySight],
                confirmAnswers: [true], table: Self.emptyTable)

            let outcome = await harness.run("play")

            #expect(outcome == .completed)
            let confirmation = try #require(harness.decisions.confirmationsShown.first)
            #expect(confirmation.reasons == [.visualClick(description: "Play button")])
            let visualClick = try #require(confirmation.visualClick)
            #expect(visualClick.target.gridX == 480)
            #expect(visualClick.target.gridY == 910)
            #expect(harness.model.requests.last?.imagesPNG == [visualClick.screenshotPNG])
            let performed = try #require(harness.executor.performed.first)
            #expect(performed.visualTarget == visualClick.target)
            #expect(performed.targetElement == nil)
            let performedLines = try await harness.auditLog.readAllEvents()
                .filter { $0.kind == .actionPerformed }.map(\.summary)
            #expect(
                performedLines == [
                    "Clicked by sight at (480, 910) of 1000 in Testbed: “Play button”"
                ])
        }
    }

    /// The window is captured again after the click and compared with the first capture.
    @Test func clickBySightChecksTheWindowChangedFromASecondCapture() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickPlayPlan, Self.playFoundBySight],
                confirmAnswers: [true], table: Self.emptyTable)

            _ = await harness.run("play")

            #expect(harness.screenshotter.captures == 2)
        }
    }

    @Test func declinedClickBySightStopsWithoutClicking() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickPlayPlan, Self.playFoundBySight],
                confirmAnswers: [false], table: Self.emptyTable)

            #expect(await harness.run("play") == .stopped(.panelCancelled))
            #expect(harness.executor.performed.isEmpty)
        }
    }

    /// Asking only before danger still asks for a click by sight.
    @Test func clickBySightAsksEvenWhenOnlyDangerAsks() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickPlayPlan, Self.playFoundBySight],
                confirmAnswers: [true], table: Self.emptyTable)

            let outcome = await harness.run(
                "play", runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy)))

            #expect(outcome == .completed)
            #expect(harness.decisions.confirmationsShown.count == 1)
        }
    }

    @Test func modelFindingNoMatchingControlLooksBySight() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    Self.clickPlayPlan,
                    #"{"elementNumber":0,"blocked":true,"reason":"No play button"}"#,
                    Self.playFoundBySight,
                ],
                confirmAnswers: [true])

            #expect(await harness.run("play") == .completed)
            #expect(harness.executor.performed.first?.visualTarget?.description == "Play button")
        }
    }

    @Test func nothingFoundBySightStopsAsTargetNotFound() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    Self.clickPlayPlan,
                    #"{"description":"","found":false,"x":0,"y":0,"reason":"Nothing like Play"}"#,
                ],
                table: Self.emptyTable)

            let outcome = await harness.run("play")

            #expect(outcome == .blocked(.unknownTarget(description: "Play"), stepNumber: 1))
            #expect(harness.decisions.confirmationsShown.isEmpty)
            #expect(harness.executor.performed.isEmpty)
        }
    }

    @Test func pointInTheTitleBarIsDeniedWithoutAsking() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    Self.clickPlayPlan,
                    #"{"description":"Close button","found":true,"x":10,"y":5}"#,
                ],
                table: Self.emptyTable)

            let outcome = await harness.run("play")

            #expect(
                outcome
                    == .blocked(
                        .visualTargetOutsideWindow(description: "Close button"), stepNumber: 1))
            #expect(harness.decisions.confirmationsShown.isEmpty)
        }
    }

    /// Checkers answer only about labelled options, so a point found by sight is not sent.
    @Test func clickBySightIsNotSentToTheCheckers() async throws {
        try await withTemporaryDirectory { directory in
            let saved = SavedExamples()
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickPlayPlan, Self.playFoundBySight],
                confirmAnswers: [true], table: Self.emptyTable)
            let disagreeingChecker = ScriptedChecker(
                name: "Laya",
                verdict: .confidentlyDisagrees(alternative: Self.archiveButton, probability: 0.9))

            _ = await harness.run(
                "play",
                runner: harness.makeRunner(
                    checkers: [disagreeingChecker],
                    layaExampleSaver: { example in saved.append(example) }))

            #expect(
                harness.decisions.confirmationsShown.first?.reasons == [
                    .visualClick(description: "Play button")
                ])
            #expect(saved.examples.isEmpty)
        }
    }
}
