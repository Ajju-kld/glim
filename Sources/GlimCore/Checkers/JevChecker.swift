/// Optional second opinion from TypeSafe's hosted Jev model. Off by default; when on, it sees
/// the goal, step, app name, window title and candidate labels — never screenshots or screen
/// text — and never anything from excluded apps.
public struct JevChecker: TargetChecker {
    /// Business rule: pinned so confidence thresholds don't shift when TypeSafe moves the
    /// `jev-latest` alias.
    public static let pinnedModel = "jev-1.13.0"

    /// Shown in confirmation panels.
    public let name = "Jev"
    private let reviewer: SystemOneTargetReviewer
    private let apiKey: @Sendable () throws -> String
    private let excludedBundleIdentifiers: Set<String>

    /// Creates a Jev checker.
    ///
    /// - Parameters:
    ///   - transport: Must enforce the network policy, which blocks Jev unless enabled.
    ///   - apiKey: Reads the TypeSafe key, from the Keychain in the live app.
    ///   - excludedBundleIdentifiers: Apps whose labels are never sent.
    ///   - confidenceThreshold: Minimum probability for a disagreement to count.
    public init(
        transport: any HTTPTransport,
        apiKey: @escaping @Sendable () throws -> String,
        excludedBundleIdentifiers: Set<String>,
        confidenceThreshold: Double = CheckerTuning.disagreementConfidenceThreshold
    ) {
        reviewer = SystemOneTargetReviewer(
            endpoint: .jev, modelName: Self.pinnedModel, transport: transport,
            confidenceThreshold: confidenceThreshold)
        self.apiKey = apiKey
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
    }

    /// Asks Jev which candidate performs the step, unless the app is excluded.
    public func review(_ request: TargetReviewRequest) async -> CheckerVerdict {
        if let bundleIdentifier = request.step.app?.bundleIdentifier,
            excludedBundleIdentifiers.contains(bundleIdentifier)
        {
            return .abstains(reason: "This app is never sent to Jev.")
        }
        let key: String
        do {
            key = try apiKey()
        } catch {
            return .unavailable(reason: "No Jev API key: \(error.localizedDescription)")
        }
        return await reviewer.review(request, bearerToken: key)
    }
}
