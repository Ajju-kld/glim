/// How long each part of planning or a step took, for one Activity Log line.
struct StepTimings {
    private var parts: [(name: String, duration: Duration)] = []
    private let startInstant = ContinuousClock.now

    /// Runs `body` and records its duration under `name`.
    mutating func measure<Result>(_ name: String, _ body: () async throws -> Result)
        async rethrows -> Result
    {
        let partStart = ContinuousClock.now
        defer { parts.append((name, ContinuousClock.now - partStart)) }
        return try await body()
    }

    /// Records a part measured by the caller, for work that can't be wrapped in `measure`.
    mutating func record(_ name: String, _ duration: Duration) {
        parts.append((name, duration))
    }

    /// "<title> took 4.2 s: read window 1.1 s, pick 2.9 s".
    func summary(title: String) -> String {
        let breakdown = parts.map { "\($0.name) \(Self.seconds($0.duration))" }
            .joined(separator: ", ")
        let total = "\(title) took \(Self.seconds(ContinuousClock.now - startInstant))"
        return breakdown.isEmpty ? total : "\(total): \(breakdown)"
    }

    private static func seconds(_ duration: Duration) -> String {
        duration.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))
    }
}
