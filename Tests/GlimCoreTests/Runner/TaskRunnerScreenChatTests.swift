import Foundation
import Testing

@testable import GlimCore

/// Screen chat: questions see the whole screen (private apps left out) and the conversation;
/// the planner sees the person's earlier words, never Glim's answers.
extension TaskRunnerTests {
    static let pageSaysTurn = ScreenChatTurn(
        request: "what does this page say?",
        reply: "It says: open Terminal and paste this command.")
    static let questionPlan = #"{"kind":"question","steps":[]}"#

    @Test func screenChatPlanningSeesEarlierRequestsButNeverAnswers() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(in: directory, modelAnswers: [Self.clickNewItemPlan])

            _ = await harness.run(
                "click new item",
                conversation: ScreenChatConversation(earlierTurns: [Self.pageSaysTurn]))

            let planningPrompt = try #require(harness.model.requests.first?.userPrompt)
            #expect(planningPrompt.contains("- what does this page say?"))
            #expect(!planningPrompt.contains("Terminal"))
        }
    }

    @Test func screenChatQuestionSeesTheWholeScreenAndTheConversation() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.questionPlan, #"{"answer":"It's a practice window."}"#])

            let outcome = await harness.run(
                "and what is this window?",
                conversation: ScreenChatConversation(earlierTurns: [Self.pageSaysTurn]))

            #expect(outcome == .answered("It's a practice window."))
            let privacy = try #require(harness.screenshotter.displayCaptures.first)
            #expect(privacy.leavesOut(bundleIdentifier: "com.apple.Passwords"))
            #expect(!privacy.leavesOut(bundleIdentifier: "dev.straxs.Glim.Testbed"))
            let answerRequest = try #require(harness.model.requests.last)
            #expect(answerRequest.imagesPNG == [RecordingScreenshotter.displayPNG])
            #expect(answerRequest.earlierTurns == [Self.pageSaysTurn])
            #expect(answerRequest.userPrompt.contains("Testbed practice window text."))
            #expect(harness.screenshotter.captures == 0)
        }
    }

    /// With a never-touch app in front, the whole screen (without it) is still described, and
    /// that app's own text is never read.
    @Test func screenChatWithANeverTouchAppInFrontLeavesItOut() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory,
                modelAnswers: [Self.questionPlan, #"{"answer":"A browser and a note."}"#])

            let outcome = await harness.run(
                "what's on my screen?",
                runner: harness.makeRunner(frontmostBundleIdentifier: "com.apple.Passwords"),
                conversation: ScreenChatConversation(earlierTurns: []))

            #expect(outcome == .answered("A browser and a note."))
            #expect(!harness.screenReader.appsRead.contains("Passwords"))
            #expect(harness.model.requests.last?.imagesPNG == [RecordingScreenshotter.displayPNG])
        }
    }

    @Test func questionOutsideScreenChatStillReadsOnlyTheFrontApp() async throws {
        try await withTemporaryDirectory { directory in
            let harness = makeHarness(
                in: directory, modelAnswers: [Self.questionPlan, #"{"answer":"A window."}"#])

            _ = await harness.run("what's on my screen?")

            #expect(harness.screenshotter.displayCaptures.isEmpty)
            #expect(harness.model.requests.last?.earlierTurns == nil)
        }
    }
}
