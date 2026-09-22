/// Second opinion from the local Laya decision service at `127.0.0.1:8791` (v1). Laya v2 will
/// run in-process with CoreML behind this same ``TargetChecker`` interface.
public struct LayaChecker: TargetChecker {
    /// Shown in confirmation panels.
    public let name = "Laya"
    private let reviewer: SystemOneTargetReviewer

    /// Creates a checker that reaches the service through `transport`.
    public init(
        transport: any HTTPTransport,
        confidenceThreshold: Double = CheckerTuning.disagreementConfidenceThreshold
    ) {
        reviewer = SystemOneTargetReviewer(
            endpoint: .layaService, modelName: nil, transport: transport,
            confidenceThreshold: confidenceThreshold)
    }

    /// Asks Laya which candidate performs the step.
    public func review(_ request: TargetReviewRequest) async -> CheckerVerdict {
        await reviewer.review(request, bearerToken: nil)
    }
}
