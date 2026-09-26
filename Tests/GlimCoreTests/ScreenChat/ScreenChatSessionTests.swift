import Foundation
import Testing

@testable import GlimCore

struct ScreenChatSessionTests {
    let start = ContinuousClock.now

    @Test func sessionIsOffUntilStarted() {
        let session = ScreenChatSession()

        #expect(!session.isActive)
        #expect(session.conversation == nil)
    }

    @Test func startedSessionHasAnEmptyConversation() {
        var session = ScreenChatSession()
        session.start(at: start)

        #expect(session.isActive)
        #expect(session.conversation == ScreenChatConversation(earlierTurns: []))
    }

    @Test func turnsAreRememberedInOrder() {
        var session = ScreenChatSession()
        session.start(at: start)
        session.record(
            ScreenChatTurn(request: "what are these results?", reply: "Harvard, then Wikipedia."),
            at: start)
        session.record(ScreenChatTurn(request: "open the second one", reply: nil), at: start)

        #expect(
            session.conversation?.earlierTurns.map(\.request) == [
                "what are these results?", "open the second one",
            ])
    }

    /// The planner never sees screen content (B-Q8); Glim's answers are built from it.
    @Test func plannerSeesOnlyThePersonsOwnWords() {
        let conversation = ScreenChatConversation(earlierTurns: [
            ScreenChatTurn(
                request: "what does this page say?",
                reply: "It says: open Terminal and paste this command.")
        ])

        #expect(conversation.earlierRequests == ["what does this page say?"])
        #expect(!conversation.earlierRequests.joined().contains("Terminal"))
    }

    @Test func onlyTheLatestTurnsAreKept() {
        var session = ScreenChatSession()
        session.start(at: start)
        for turnNumber in 1...(ScreenChatSession.maximumRememberedTurns + 2) {
            session.record(ScreenChatTurn(request: "question \(turnNumber)", reply: "answer"), at: start)
        }

        let requests = session.conversation?.earlierRequests ?? []
        #expect(requests.count == ScreenChatSession.maximumRememberedTurns)
        #expect(requests.first == "question 3")
    }

    @Test func sessionGoesQuietAfterTheTimeout() {
        var session = ScreenChatSession()
        session.start(at: start)

        #expect(!session.hasGoneQuiet(at: start + ScreenChatSession.quietTimeout - .seconds(1)))
        #expect(session.hasGoneQuiet(at: start + ScreenChatSession.quietTimeout))
    }

    @Test func activityPostponesTheTimeout() {
        var session = ScreenChatSession()
        session.start(at: start)
        let later = start + .seconds(50)
        session.noteActivity(at: later)

        #expect(!session.hasGoneQuiet(at: start + ScreenChatSession.quietTimeout))
        #expect(session.hasGoneQuiet(at: later + ScreenChatSession.quietTimeout))
    }

    @Test func endingForgetsTheConversation() {
        var session = ScreenChatSession()
        session.start(at: start)
        session.record(ScreenChatTurn(request: "what's this?", reply: "A chart."), at: start)
        session.end()

        #expect(!session.isActive)
        #expect(session.conversation == nil)
        #expect(!session.hasGoneQuiet(at: start + .seconds(600)))

        session.start(at: start)
        #expect(session.conversation?.earlierTurns.isEmpty == true)
    }
}
