import Foundation
import Testing

@testable import GlimCore

struct SystemOneCheckerTests {
    let newNote = UIElementSnapshot.fixture(number: 1, label: "New Note")
    let archive = UIElementSnapshot.fixture(number: 2, label: "Archive")

    func reviewRequest(
        app: AppIdentity = .notes, candidates: [UIElementSnapshot]? = nil,
        chosen: UIElementSnapshot? = nil
    ) -> TargetReviewRequest {
        TargetReviewRequest(
            goal: "open notes and add a note",
            step: ScreenedStep(
                number: 2, action: .click(appName: app.displayName, target: "New Note"), app: app,
                tier: .fullControl),
            windowTitle: "Notes",
            candidates: candidates ?? [newNote, archive],
            chosenElement: chosen ?? newNote)
    }

    func answer(choice: String, probabilities: [String: Double]) -> FakeHTTPTransport.Reply {
        let probabilityText = probabilities.sorted { $0.key < $1.key }
            .map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
        return .response(
            statusCode: 200,
            body:
                #"{"answers":{"target":{"type":"choice","choice":"\#(choice)","probabilities":{\#(probabilityText)},"confidence":0.8}}}"#
        )
    }

    func layaChecker(replies: [FakeHTTPTransport.Reply]) -> (LayaChecker, FakeHTTPTransport) {
        let fakeTransport = FakeHTTPTransport(replies: replies)
        return (LayaChecker(transport: fakeTransport), fakeTransport)
    }

    // MARK: - Laya

    @Test func sendsAChoiceQuestionOverTheCandidates() async throws {
        let (checker, fakeTransport) = layaChecker(replies: [
            answer(choice: "1", probabilities: ["1": 0.9, "2": 0.1])
        ])

        _ = await checker.review(reviewRequest())

        let sentRequest = try #require(fakeTransport.sentRequests.first)
        #expect(sentRequest.url?.absoluteString == "http://127.0.0.1:8791/v1/systemone")
        #expect(sentRequest.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try jsonObject(of: sentRequest)
        #expect(body["model"] == nil)
        let state = try #require(body["state"] as? [String: Any])
        #expect(state["app"] as? String == "Notes")
        #expect(state["step"] as? String == "Click “New Note” in Notes")
        let question = try #require(
            (body["questions"] as? [String: Any])?["target"] as? [String: Any])
        #expect(question["type"] as? String == "choice")
        #expect(
            question["criteria"] as? [String: String] == [
                "1": "New Note (Button)", "2": "Archive (Button)",
            ])
    }

    @Test func samePickAgrees() async {
        let (checker, _) = layaChecker(replies: [
            answer(choice: "1", probabilities: ["1": 0.9, "2": 0.1])
        ])

        #expect(await checker.review(reviewRequest()) == .agrees)
    }

    @Test func confidentDifferentPickDisagrees() async {
        let (checker, _) = layaChecker(replies: [
            answer(choice: "2", probabilities: ["1": 0.2, "2": 0.8])
        ])

        #expect(
            await checker.review(reviewRequest())
                == .confidentlyDisagrees(alternative: archive, probability: 0.8))
    }

    @Test func unsureDifferentPickAbstains() async {
        let (checker, _) = layaChecker(replies: [
            answer(choice: "2", probabilities: ["1": 0.45, "2": 0.55])
        ])

        guard case .abstains = await checker.review(reviewRequest()) else {
            Issue.record("Expected the checker to abstain")
            return
        }
    }

    @Test func unknownOptionAbstains() async {
        let (checker, _) = layaChecker(replies: [answer(choice: "9", probabilities: ["9": 0.99])])

        guard case .abstains = await checker.review(reviewRequest()) else {
            Issue.record("Expected the checker to abstain")
            return
        }
    }

    @Test func stoppedServiceIsUnavailable() async {
        let (checker, _) = layaChecker(replies: [.failure(.cannotConnectToHost)])

        guard case .unavailable = await checker.review(reviewRequest()) else {
            Issue.record("Expected unavailable")
            return
        }
    }

    @Test func serverErrorIsUnavailable() async {
        let (checker, _) = layaChecker(replies: [
            .response(statusCode: 422, body: #"{"error":"bad"}"#)
        ])

        guard case .unavailable = await checker.review(reviewRequest()) else {
            Issue.record("Expected unavailable")
            return
        }
    }

    @Test func manyCandidatesAreShortlistedToTwenty() async throws {
        let fillers = (3...40).map { UIElementSnapshot.fixture(number: $0, label: "Filler \($0)") }
        let (checker, fakeTransport) = layaChecker(replies: [
            answer(choice: "1", probabilities: ["1": 0.9])
        ])

        _ = await checker.review(reviewRequest(candidates: [archive] + fillers + [newNote]))

        let body = try jsonObject(of: try #require(fakeTransport.sentRequests.first))
        let question = try #require(
            (body["questions"] as? [String: Any])?["target"] as? [String: Any])
        let criteria = try #require(question["criteria"] as? [String: String])
        #expect(criteria.count == CheckerTuning.shortlistLimit)
        #expect(criteria["1"] == "New Note (Button)")
    }

    @Test func pickOutsideTheShortlistAbstainsWithoutAsking() async {
        let fillers = (3...40).map {
            UIElementSnapshot.fixture(number: $0, label: "New Note copy \($0)")
        }
        let oddPick = UIElementSnapshot.fixture(number: 99, label: "Zebra")
        let (checker, fakeTransport) = layaChecker(replies: [])

        let verdict = await checker.review(
            reviewRequest(candidates: fillers + [oddPick], chosen: oddPick))

        guard case .abstains = verdict else {
            Issue.record("Expected the checker to abstain, got \(verdict)")
            return
        }
        #expect(fakeTransport.sentRequests.isEmpty)
    }

    // MARK: - Jev

    func jevChecker(
        replies: [FakeHTTPTransport.Reply], isJevEnabled: Bool = true,
        apiKey: @escaping @Sendable () throws -> String = { "test-key" }
    ) -> (JevChecker, FakeHTTPTransport) {
        let fakeTransport = FakeHTTPTransport(replies: replies)
        let transport = PolicyEnforcingTransport(
            base: fakeTransport, policy: NetworkPolicy(isJevEnabled: isJevEnabled))
        let checker = JevChecker(
            transport: transport, apiKey: apiKey,
            excludedBundleIdentifiers: JevSettings.safeDefaults.excludedBundleIdentifiers)
        return (checker, fakeTransport)
    }

    @Test func jevSendsBearerKeyAndPinnedModel() async throws {
        let (checker, fakeTransport) = jevChecker(replies: [
            answer(choice: "1", probabilities: ["1": 0.9])
        ])

        #expect(await checker.review(reviewRequest()) == .agrees)

        let sentRequest = try #require(fakeTransport.sentRequests.first)
        #expect(sentRequest.url?.absoluteString == "https://api.typesafe.ai:443/v1/systemone")
        #expect(sentRequest.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(try jsonObject(of: sentRequest)["model"] as? String == JevChecker.pinnedModel)
    }

    @Test func jevNeverSeesExcludedApps() async {
        let (checker, fakeTransport) = jevChecker(replies: [])

        let verdict = await checker.review(reviewRequest(app: .messages))

        guard case .abstains = verdict else {
            Issue.record("Expected the checker to abstain, got \(verdict)")
            return
        }
        #expect(fakeTransport.sentRequests.isEmpty)
    }

    @Test func jevWithoutAKeyIsUnavailable() async {
        struct MissingKey: Error {}
        let (checker, fakeTransport) = jevChecker(replies: [], apiKey: { throw MissingKey() })

        guard case .unavailable = await checker.review(reviewRequest()) else {
            Issue.record("Expected unavailable")
            return
        }
        #expect(fakeTransport.sentRequests.isEmpty)
    }

    @Test func jevBlockedByPolicyIsUnavailable() async {
        let (checker, fakeTransport) = jevChecker(replies: [], isJevEnabled: false)

        guard case .unavailable = await checker.review(reviewRequest()) else {
            Issue.record("Expected unavailable")
            return
        }
        #expect(fakeTransport.sentRequests.isEmpty)
    }
}
