import Testing

@testable import GlimCore

struct ScriptedChecker: TargetChecker {
    let name: String
    let verdict: CheckerVerdict

    func review(_ request: TargetReviewRequest) async -> CheckerVerdict {
        verdict
    }
}

struct CheckerConsensusTests {
    let archive = UIElementSnapshot.fixture(number: 2, label: "Archive")
    let request = TargetReviewRequest(
        goal: "goal",
        step: ScreenedStep(
            number: 1, action: .click(appName: "Notes", target: "New Note"), app: .notes,
            tier: .fullControl),
        windowTitle: nil,
        candidates: [],
        chosenElement: UIElementSnapshot.fixture(number: 1, label: "New Note"))

    @Test func agreementAndAbstentionRaiseNoConcerns() async {
        let consensus = CheckerConsensus(checkers: [
            ScriptedChecker(name: "Laya", verdict: .agrees),
            ScriptedChecker(name: "Jev", verdict: .abstains(reason: "excluded app")),
        ])

        let result = await consensus.review(request)

        #expect(result.concerns.isEmpty)
        #expect(result.outcomes.map(\.checkerName) == ["Laya", "Jev"])
    }

    @Test func confidentDisagreementAndOfflineCheckersAreConcerns() async {
        let consensus = CheckerConsensus(checkers: [
            ScriptedChecker(
                name: "Laya", verdict: .confidentlyDisagrees(alternative: archive, probability: 0.9)
            ),
            ScriptedChecker(name: "Jev", verdict: .unavailable(reason: "HTTP 529")),
        ])

        let result = await consensus.review(request)

        #expect(
            result.concerns == [
                .checkerDisagrees(checkerName: "Laya", checkerChoice: "Archive"),
                .checkerOffline(checkerName: "Jev"),
            ])
    }

    @Test func noCheckersMeansNoConcerns() async {
        #expect(await CheckerConsensus(checkers: []).review(request).concerns.isEmpty)
    }
}
