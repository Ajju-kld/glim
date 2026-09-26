import Foundation
import Testing

@testable import GlimCore

/// In screen chat the planner sees the person's earlier requests, so "open the second one" has
/// something to refer to; answers see the whole conversation.
struct ScreenChatPlannerTests {
    static func context(earlierRequests: [String]) -> PlanningContext {
        PlanningContext(
            goal: "open the second one", frontAppName: "Google Chrome", windowTitle: "Results",
            elementLabels: ["Harvard University", "Wikipedia"],
            installedAppNames: ["Google Chrome"], runningAppNames: ["Google Chrome"],
            earlierRequests: earlierRequests)
    }

    @Test func planningPromptListsEarlierRequestsBeforeTheNewOne() throws {
        let prompt = Planner.planningPrompt(
            for: Self.context(earlierRequests: ["search for harvard university"]))

        let earlierStart = try #require(prompt.range(of: "- search for harvard university"))
        let requestStart = try #require(prompt.range(of: "Request: open the second one"))
        #expect(prompt.contains("Earlier requests in this conversation"))
        #expect(earlierStart.lowerBound < requestStart.lowerBound)
    }

    @Test func planningPromptOutsideScreenChatIsUnchanged() {
        let prompt = Planner.planningPrompt(for: Self.context(earlierRequests: []))

        #expect(!prompt.contains("Earlier requests"))
    }

    @Test func screenChatQuestionSendsTheConversation() async throws {
        let model = FakeLanguageModel(answers: [.success(#"{"answer":"The second is Wikipedia."}"#)]
        )
        let turns = [ScreenChatTurn(request: "what are these results?", reply: "Two results.")]

        let answer = try await Planner(languageModel: model).answerQuestion(
            "and the second one?", screenText: "Harvard. Wikipedia.",
            screenshotPNG: Data([0x89, 0x50]), earlierTurns: turns)

        #expect(answer == "The second is Wikipedia.")
        #expect(model.requests.first?.earlierTurns == turns)
        #expect(model.requests.first?.imagesPNG == [Data([0x89, 0x50])])
    }

    @Test func questionOutsideScreenChatHasNoConversation() async throws {
        let model = FakeLanguageModel(answers: [.success(#"{"answer":"A chart."}"#)])

        _ = try await Planner(languageModel: model).answerQuestion(
            "what's this?", screenText: "Chart", screenshotPNG: nil)

        #expect(model.requests.first?.earlierTurns == nil)
    }
}
