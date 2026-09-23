import Foundation
import Testing

@testable import GlimCore

struct LayaPickerTests {
    let newNote = UIElementSnapshot.fixture(number: 1, label: "New Note")
    let archive = UIElementSnapshot.fixture(number: 2, label: "Archive")
    let clickNewNote = StepAction.click(appName: "Notes", target: "New Note")
    let goal = "open notes and add a note"

    func answer(choice: String, probabilities: [String: Double]) -> FakeHTTPTransport.Reply {
        let probabilityText = probabilities.sorted { $0.key < $1.key }
            .map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
        return .response(
            statusCode: 200,
            body:
                #"{"answers":{"target":{"type":"choice","choice":"\#(choice)","probabilities":{\#(probabilityText)}}}}"#
        )
    }

    func layaPicker(replies: [FakeHTTPTransport.Reply]) -> (LayaPicker, FakeHTTPTransport) {
        let fakeTransport = FakeHTTPTransport(replies: replies)
        return (LayaPicker(transport: fakeTransport), fakeTransport)
    }

    @Test func sendsAChoiceQuestionToTheLocalLayaService() async throws {
        let (picker, fakeTransport) = layaPicker(replies: [
            answer(choice: "1", probabilities: ["1": 0.9, "2": 0.1])
        ])

        _ = await picker.pick(
            for: clickNewNote, goal: goal, appName: "Notes", windowTitle: "All iCloud",
            among: [newNote, archive])

        let sentRequest = try #require(fakeTransport.sentRequests.first)
        #expect(sentRequest.url?.absoluteString == "http://127.0.0.1:8791/v1/systemone")
        let state = try #require(try jsonObject(of: sentRequest)["state"] as? [String: Any])
        #expect(state["app"] as? String == "Notes")
        #expect(state["windowTitle"] as? String == "All iCloud")
        let question = try #require(
            (try jsonObject(of: sentRequest)["questions"] as? [String: Any])?["target"]
                as? [String: Any])
        #expect(
            question["criteria"] as? [String: String] == [
                "1": "New Note (Button)", "2": "Archive (Button)",
            ])
    }

    @Test func confidentPickIsUsed() async {
        let (picker, _) = layaPicker(replies: [
            answer(choice: "2", probabilities: ["1": 0.1, "2": 0.9])
        ])

        #expect(
            await picker.pick(
                for: clickNewNote, goal: goal, appName: "Notes", windowTitle: nil,
                among: [newNote, archive]) == archive)
    }

    @Test func unsurePickIsIgnored() async {
        let (picker, _) = layaPicker(replies: [
            answer(choice: "1", probabilities: ["1": 0.6, "2": 0.4])
        ])

        #expect(
            await picker.pick(
                for: clickNewNote, goal: goal, appName: "Notes", windowTitle: nil,
                among: [newNote, archive]) == nil)
    }

    @Test func pickOutsideTheCandidatesIsIgnored() async {
        let (picker, _) = layaPicker(replies: [
            answer(choice: "7", probabilities: ["7": 0.99])
        ])

        #expect(
            await picker.pick(
                for: clickNewNote, goal: goal, appName: "Notes", windowTitle: nil,
                among: [newNote, archive]) == nil)
    }

    @Test func unreachableLayaFallsBackQuietly() async {
        let (picker, _) = layaPicker(replies: [.failure(.cannotConnectToHost)])

        #expect(
            await picker.pick(
                for: clickNewNote, goal: goal, appName: "Notes", windowTitle: nil,
                among: [newNote, archive]) == nil)
    }

    @Test func errorStatusFallsBackQuietly() async {
        let (picker, _) = layaPicker(replies: [.response(statusCode: 503, body: "")])

        #expect(
            await picker.pick(
                for: clickNewNote, goal: goal, appName: "Notes", windowTitle: nil,
                among: [newNote, archive]) == nil)
    }

    @Test func warmUpAsksLayaOnceAndIgnoresTheAnswer() async {
        let (picker, fakeTransport) = layaPicker(replies: [
            answer(choice: "1", probabilities: ["1": 0.9, "2": 0.1])
        ])

        await picker.warmUp()

        #expect(fakeTransport.sentRequests.count == 1)
        #expect(
            fakeTransport.sentRequests.first?.timeoutInterval == LayaPicker.warmUpTimeoutSeconds)
    }

    @Test func warmUpWithLayaDownIsQuiet() async {
        let (picker, fakeTransport) = layaPicker(replies: [.failure(.cannotConnectToHost)])

        await picker.warmUp()

        #expect(fakeTransport.sentRequests.count == 1)
    }

    @Test func singleCandidateIsNotSentToLaya() async {
        let (picker, fakeTransport) = layaPicker(replies: [])

        #expect(
            await picker.pick(
                for: clickNewNote, goal: goal, appName: "Notes", windowTitle: nil, among: [newNote])
                == nil)
        #expect(fakeTransport.sentRequests.isEmpty)
    }
}
