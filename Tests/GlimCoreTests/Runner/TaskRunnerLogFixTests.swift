import Foundation
import Testing

@testable import GlimCore

/// Fixes for problems seen in a real Activity Log: fields that couldn't be clicked, the same
/// rejected pick offered again, a silent look by sight, and a confirmation wait hidden in the
/// step timing.
extension TaskRunnerTests {
    static let settingsButtonPlan =
        #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Settings"}]}"#

    /// A window with two buttons, neither of which is Settings.
    static let twoButtonTable = ElementTable(
        elements: [newItemButton, deleteButton],
        handleIndexByElementNumber: [1: 1, 2: 2],
        readableText: String(repeating: "Testbed practice window text. ", count: 10),
        wasTruncated: false)

    @Test func clickOnATextFieldIsPerformedOnThatField() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Notes field"}]}"#
                ])

            #expect(await harness.run("click the notes field") == .completed)
            #expect(harness.executor.performed.first?.targetElement == Self.notesField)
        }
    }

    @Test func rejectedPickIsNotOfferedAgain() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    Self.settingsButtonPlan,
                    #"{"elementNumber":2,"blocked":false}"#,
                    #"{"elementNumber":0,"blocked":true,"reason":"No settings control"}"#,
                    Self.playFoundBySight,
                ],
                confirmAnswers: [true])

            let outcome = await harness.run(
                "open settings",
                runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy)))

            #expect(outcome == .completed)
            let retryPrompt = try #require(harness.model.requests.dropFirst(2).first?.userPrompt)
            #expect(!retryPrompt.contains("] Delete ("))
            #expect(retryPrompt.contains("] New Item ("))
        }
    }

    /// Every control was rejected in turn: nothing is left to offer, so a click looks by sight
    /// instead of asking the model to repeat itself.
    @Test func clickWithEveryControlRejectedLooksBySight() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    Self.settingsButtonPlan,
                    #"{"elementNumber":1,"blocked":false}"#,
                    #"{"elementNumber":2,"blocked":false}"#,
                    Self.playFoundBySight,
                ],
                confirmAnswers: [true], table: Self.twoButtonTable)

            let outcome = await harness.run(
                "open settings",
                runner: harness.makeRunner(policy: ChangingPolicy(Self.dangerOnlyPolicy)))

            #expect(outcome == .completed)
            #expect(harness.model.requests.count == 4)
            #expect(harness.executor.performed.first?.visualTarget != nil)
        }
    }

    @Test func lookingBySightIsLoggedAndTimed() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.clickPlayPlan, Self.playFoundBySight],
                confirmAnswers: [true], table: Self.emptyTable)

            _ = await harness.run("play")

            let events = try await harness.auditLog.readAllEvents()
            #expect(
                events.contains { event in
                    event.kind == .lookingBySight
                        && event.summary == "Looking at a screenshot of Testbed for “Play”"
                })
            let timing = try #require(events.last { $0.kind == .stepTiming }?.summary)
            #expect(timing.contains("look "))
        }
    }

    @Test func lookingBySightAfterTheModelFindsNothingIsTimedSeparately() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    Self.clickPlayPlan,
                    #"{"elementNumber":0,"blocked":true,"reason":"No play button"}"#,
                    Self.playFoundBySight,
                ],
                confirmAnswers: [true])

            _ = await harness.run("play")

            let timing = try #require(
                try await harness.auditLog.readAllEvents().last { $0.kind == .stepTiming }?.summary
            )
            #expect(timing.contains("pick "))
            #expect(timing.contains("look "))
        }
    }

    @Test func confirmationWaitIsTimedOnItsOwn() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [
                    #"{"kind":"task","steps":[{"action":"click","app":"Testbed","target":"Send"}]}"#
                ],
                confirmAnswers: [true])

            _ = await harness.run("send it")

            let timing = try #require(
                try await harness.auditLog.readAllEvents().last { $0.kind == .stepTiming }?.summary
            )
            #expect(timing.contains("waiting for you "))
        }
    }

    /// The log names the control each step acted on and who chose it, so a wrong click (such
    /// as "first search result" landing on something else) can be seen afterwards.
    @Test func clickLogsTheControlItActedOnAndWhoChoseIt() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(in: directory, modelAnswers: [Self.clickNewItemPlan])

            #expect(await harness.run("click new item") == .completed)

            let performedLines = try await harness.auditLog.readAllEvents()
                .filter { $0.kind == .actionPerformed }.map(\.summary)
            #expect(
                performedLines == [
                    "Click “New Item” in Testbed → [1] New Item (Button), found by its exact label"
                ])
        }
    }

    @Test func controlPickedByTheModelIsLoggedAsTheAIsPick() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.clickFirstButtonPlan, #"{"elementNumber":1,"blocked":false}"#],
                confirmAnswers: [true])

            #expect(await harness.run("click the first button") == .completed)

            let performedLines = try await harness.auditLog.readAllEvents()
                .filter { $0.kind == .actionPerformed }.map(\.summary)
            #expect(
                performedLines == [
                    "Click “the first button” in Testbed → [1] New Item (Button), picked by the AI"
                ])
        }
    }
}
