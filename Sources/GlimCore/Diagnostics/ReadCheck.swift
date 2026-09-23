/// What Glim could read from one app's window.
public struct ControlCounts: Sendable, Equatable {
    /// Controls offered to the model.
    public let listed: Int
    /// Controls left out because they were greyed out.
    public let greyedOut: Int
    /// Controls left out because they had no name.
    public let unnamed: Int
    /// Whether the window had more controls than the table holds.
    public let wasCutOff: Bool

    /// Creates counts.
    public init(listed: Int, greyedOut: Int, unnamed: Int, wasCutOff: Bool) {
        self.listed = listed
        self.greyedOut = greyedOut
        self.unnamed = unnamed
        self.wasCutOff = wasCutOff
    }
}

/// How well Glim can read one app.
public enum ReadCheckOutcome: Sendable, Equatable {
    case readable(ControlCounts)
    /// Fewer controls than `ReadCheck.thinControlLimit`: likely only part of the window.
    case thin(ControlCounts)
    case nothingReadable(ControlCounts)
    case couldNotRead(reason: String)
    case skipped(reason: String)
}

/// One app's line in the read check.
public struct ReadCheckResult: Sendable, Equatable, Identifiable {
    /// The app's display name.
    public let appName: String
    /// The app's bundle identifier.
    public let bundleIdentifier: String
    /// What the read found.
    public let outcome: ReadCheckOutcome

    /// Identifies the row by its app.
    public var id: String { bundleIdentifier }
}

/// Reads the front window of every open app, the same way a task does, and reports what Glim
/// could see. It never clicks, types, switches apps or asks a model, and never-touch apps are
/// not read at all.
public struct ReadCheck: Sendable {
    /// Business rule: a window offering fewer controls than this is reported as thin.
    public static let thinControlLimit = 5

    private let reader: any ScreenReading
    private let trust: AppTrustPolicy

    /// Creates a check that reads with `reader` and skips apps `trust` never touches.
    public init(reader: any ScreenReading, trust: AppTrustPolicy) {
        self.reader = reader
        self.trust = trust
    }

    /// Reads each app in turn.
    public func run(on apps: [ResolvedApp]) async -> [ReadCheckResult] {
        var results: [ReadCheckResult] = []
        for app in apps {
            results.append(
                ReadCheckResult(
                    appName: app.identity.displayName,
                    bundleIdentifier: app.identity.bundleIdentifier,
                    outcome: await outcome(for: app)))
        }
        return results
    }

    /// One line per app with counts only: no control names or screen text, so the log never
    /// holds what was on screen.
    public static func summary(of results: [ReadCheckResult]) -> String {
        let lines = results.map { result in
            "\(result.appName): \(describe(result.outcome))"
        }
        return "Read check of \(results.count) open apps. " + lines.joined(separator: "; ")
    }

    private func outcome(for app: ResolvedApp) async -> ReadCheckOutcome {
        guard trust.tier(for: app.identity) != .neverTouch else {
            return .skipped(reason: "never touched")
        }
        let table: ElementTable
        do {
            table = try await reader.snapshotFrontWindow(of: app).table
        } catch {
            return .couldNotRead(reason: error.explanation)
        }
        let counts = ControlCounts(
            listed: table.elements.count, greyedOut: table.disabledControlLabels.count,
            unnamed: table.unlabelledControlCount, wasCutOff: table.wasTruncated)
        if counts.listed == 0 {
            return .nothingReadable(counts)
        }
        return counts.listed < Self.thinControlLimit ? .thin(counts) : .readable(counts)
    }

    private static func describe(_ outcome: ReadCheckOutcome) -> String {
        switch outcome {
        case .readable(let counts): "readable, \(describe(counts))"
        case .thin(let counts): "thin, \(describe(counts))"
        case .nothingReadable(let counts): "nothing readable, \(describe(counts))"
        case .couldNotRead(let reason): "could not read: \(reason)"
        case .skipped(let reason): "skipped (\(reason))"
        }
    }

    private static func describe(_ counts: ControlCounts) -> String {
        let cutOffNote = counts.wasCutOff ? " (cut off)" : ""
        return
            "\(counts.listed) controls\(cutOffNote), \(counts.greyedOut) greyed out, \(counts.unnamed) unnamed"
    }
}
