import Foundation
import Testing

@testable import GlimCore

struct LayaExampleTests {
    static let newNote = UIElementSnapshot.fixture(number: 1, label: "New Note")
    static let secretRow = UIElementSnapshot.fixture(
        number: 2, role: "AXCell", label: "1.demo_user: Qx7.pL2@vN9^k")

    static func reviewRequest(chosen: UIElementSnapshot = newNote) -> TargetReviewRequest {
        TargetReviewRequest(
            goal: "open notes and add a note",
            step: ScreenedStep(
                number: 2, action: .click(appName: "Notes", target: "New Note"), app: .notes,
                tier: .fullControl),
            windowTitle: "Notes",
            candidates: [newNote, secretRow],
            chosenElement: chosen)
    }

    static let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func questionIsWhatLayaIsSent() {
        let question = SystemOneTargetQuestion(
            request: Self.reviewRequest(), shortlist: [Self.newNote, Self.secretRow])

        #expect(question.step == "Click “New Note” in Notes")
        #expect(question.action == "click")
        #expect(question.app == "Notes")
        #expect(
            question.instructions
                == "Which numbered control performs this step: Click “New Note” in Notes?")
        #expect(question.options["1"] == "New Note (Button)")
        #expect(question.options["2"] == "1.demo_user: Qx7.pL2@vN9^k (Cell)")
    }

    @Test func secretLookingWordsAreMasked() {
        #expect(SecretMasker.masked("1.demo_user: Qx7.pL2@vN9^k") == "1.demo_user: [hidden]")
        #expect(SecretMasker.masked("Liked Songs • Alex Morgan") == "Liked Songs • Alex Morgan")
        #expect(SecretMasker.masked("ghp_4fKq9ZtX2mB7") == "[hidden]")
        #expect(SecretMasker.masked("Version 26.6.2") == "Version 26.6.2")
    }

    @Test func exampleIsSavedWhenLayaAnswered() throws {
        let example = try #require(
            LayaExample.make(
                from: Self.reviewRequest(),
                outcome: CheckerOutcome(checkerName: LayaChecker.checkerName, verdict: .agrees),
                id: UUID(), createdAt: Self.createdAt))

        #expect(example.plannerPick == "1")
        #expect(example.layaVerdict == "agrees")
        #expect(example.question.options["2"] == "1.demo_user: [hidden] (Cell)")
        #expect(example.review == nil)
    }

    @Test(arguments: [
        CheckerOutcome(checkerName: LayaChecker.checkerName, verdict: .unavailable(reason: "down")),
        CheckerOutcome(checkerName: "Jev", verdict: .agrees),
    ])
    func noExampleWithoutAnAnswerFromLaya(outcome: CheckerOutcome) {
        #expect(
            LayaExample.make(
                from: Self.reviewRequest(), outcome: outcome, id: UUID(),
                createdAt: Self.createdAt) == nil)
    }

    @Test func storeKeepsExamplesAndReviews() async throws {
        try await withTemporaryDirectory { directory in
            let store = LayaExampleStore(directory: directory)
            let example = try #require(
                LayaExample.make(
                    from: Self.reviewRequest(),
                    outcome: CheckerOutcome(checkerName: LayaChecker.checkerName, verdict: .agrees),
                    id: UUID(), createdAt: Self.createdAt))

            try await store.append(example)
            try await store.saveReview(
                LayaReview(correctOption: "1", reviewedAt: Self.createdAt), forExampleID: example.id
            )
            let saved = try await store.allExamples()

            #expect(saved.count == 1)
            #expect(saved.first?.review?.correctOption == "1")

            try await store.deleteAll()
            #expect(try await store.allExamples().isEmpty)
        }
    }

    @Test func summaryCountsReviewsAndApps() {
        let reviewed = LayaExample(
            id: UUID(), createdAt: Self.createdAt,
            question: SystemOneTargetQuestion(
                request: Self.reviewRequest(), shortlist: [Self.newNote]),
            plannerPick: "1", layaVerdict: "agrees",
            review: LayaReview(correctOption: "1", reviewedAt: Self.createdAt))
        let unreviewed = LayaExample(
            id: UUID(), createdAt: Self.createdAt, question: reviewed.question, plannerPick: "1",
            layaVerdict: "agrees", review: nil)

        let summary = LayaExampleSummary(examples: [reviewed, unreviewed])

        #expect(summary.savedCount == 2)
        #expect(summary.reviewedCount == 1)
        #expect(summary.appNames == ["Notes"])
        #expect(!summary.meetsTrainingMinimum)
    }
}
