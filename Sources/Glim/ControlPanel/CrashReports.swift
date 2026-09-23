import Foundation

/// Reads macOS's crash reports for Glim, so the dashboard can say when Glim last crashed.
enum CrashReports {
    /// One crash: when it happened, how macOS described it, and the report file.
    struct Crash: Sendable {
        let date: Date
        let description: String
        let reportURL: URL
    }

    private static let reportsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/DiagnosticReports", directoryHint: .isDirectory)
    private static let reportNamePrefix = "Glim-"
    private static let reportExtension = "ips"

    /// The newest Glim crash report, or nil when there is none.
    ///
    /// - Throws: When the reports folder or the newest report can't be read.
    static func latest() throws -> Crash? {
        let reportURLs = try FileManager.default.contentsOfDirectory(
            at: reportsDirectory, includingPropertiesForKeys: [.contentModificationDateKey]
        )
        .filter {
            $0.lastPathComponent.hasPrefix(reportNamePrefix) && $0.pathExtension == reportExtension
        }
        let datedURLs = try reportURLs.map { reportURL in
            let date =
                try reportURL.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate ?? .distantPast
            return (reportURL, date)
        }
        guard let (reportURL, date) = datedURLs.max(by: { $0.1 < $1.1 }) else {
            return nil
        }
        return Crash(date: date, description: try description(of: reportURL), reportURL: reportURL)
    }

    /// The report's exception type and signal, such as "EXC_BREAKPOINT (SIGTRAP)". A report is
    /// a one-line JSON header followed by a JSON body.
    private static func description(of reportURL: URL) throws -> String {
        let text = try String(contentsOf: reportURL, encoding: .utf8)
        guard let bodyStart = text.firstIndex(of: "\n") else {
            return "Unreadable report"
        }
        let body = try JSONSerialization.jsonObject(with: Data(text[bodyStart...].utf8))
        guard let report = body as? [String: Any],
            let exception = report["exception"] as? [String: Any],
            let type = exception["type"] as? String
        else {
            return "Unknown crash"
        }
        let signal = exception["signal"] as? String
        return signal.map { "\(type) (\($0))" } ?? type
    }
}
