import Foundation

/// The owner's verdict on one example.
public struct LayaReview: Sendable, Equatable, Codable {
    /// The option that performs the step, or nil when the owner skipped the example.
    public let correctOption: String?
    /// When the owner reviewed it.
    public let reviewedAt: Date

    /// Creates a review.
    public init(correctOption: String?, reviewedAt: Date) {
        self.correctOption = correctOption
        self.reviewedAt = reviewedAt
    }
}

/// One step Laya reviewed, kept to train it on Mac apps once the owner has reviewed it.
public struct LayaExample: Sendable, Equatable, Codable, Identifiable {
    /// Identifies the example.
    public let id: UUID
    /// When the step ran.
    public let createdAt: Date
    /// Exactly what Laya was asked, with secret-looking words hidden.
    public let question: SystemOneTargetQuestion
    /// The option the planner picked.
    public let plannerPick: String
    /// What Laya answered, in words.
    public let layaVerdict: String
    /// The owner's verdict, once given.
    public let review: LayaReview?

    /// Creates an example.
    public init(
        id: UUID, createdAt: Date, question: SystemOneTargetQuestion, plannerPick: String,
        layaVerdict: String, review: LayaReview?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.question = question
        self.plannerPick = plannerPick
        self.layaVerdict = layaVerdict
        self.review = review
    }

    /// The example for Laya's answer about `request`, or nil when Laya didn't answer (it was
    /// unreachable, another checker answered, or the pick was outside what Laya was shown).
    public static func make(
        from request: TargetReviewRequest, outcome: CheckerOutcome, id: UUID, createdAt: Date
    ) -> LayaExample? {
        guard outcome.checkerName == LayaChecker.checkerName,
            let verdictText = describe(outcome.verdict)
        else {
            return nil
        }
        let shortlist = CandidateShortlist.shortlist(
            request.candidates, targetDescription: request.step.action.targetDescription ?? "",
            limit: CheckerTuning.shortlistLimit)
        guard shortlist.contains(request.chosenElement) else {
            return nil
        }
        let question = SystemOneTargetQuestion(request: request, shortlist: shortlist)
            .mapTexts(SecretMasker.masked)
        return LayaExample(
            id: id, createdAt: createdAt, question: question,
            plannerPick: String(request.chosenElement.number), layaVerdict: verdictText,
            review: nil)
    }

    /// The same example with the owner's review.
    public func reviewed(_ review: LayaReview) -> LayaExample {
        LayaExample(
            id: id, createdAt: createdAt, question: question, plannerPick: plannerPick,
            layaVerdict: layaVerdict, review: review)
    }

    private static func describe(_ verdict: CheckerVerdict) -> String? {
        switch verdict {
        case .agrees: "agrees"
        case .confidentlyDisagrees(let alternative, let probability):
            "disagrees: option \(alternative.number) (\(probability))"
        case .abstains(let reason): "abstains: \(reason)"
        case .unavailable: nil
        }
    }
}

/// Counts shown on the Laya Training page.
public struct LayaExampleSummary: Sendable, Equatable {
    /// Business rule: reviewed examples needed before training is allowed.
    public static let minimumReviewedExamples = 200
    /// Business rule: distinct apps the reviewed examples must cover.
    public static let minimumApps = 5

    /// Every saved example.
    public let savedCount: Int
    /// Examples with a correct option chosen by the owner.
    public let reviewedCount: Int
    /// Apps the reviewed examples come from, sorted.
    public let appNames: [String]

    /// Whether there is enough reviewed data to train.
    public var meetsTrainingMinimum: Bool {
        reviewedCount >= Self.minimumReviewedExamples && appNames.count >= Self.minimumApps
    }

    /// Summarizes `examples`.
    public init(examples: [LayaExample]) {
        let reviewed = examples.filter { $0.review?.correctOption != nil }
        savedCount = examples.count
        reviewedCount = reviewed.count
        appNames = Set(reviewed.map(\.question.app)).sorted()
    }
}
