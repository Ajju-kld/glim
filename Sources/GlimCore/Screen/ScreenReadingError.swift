/// Why Glim could not read or capture the screen.
public enum ScreenReadingError: Error, Sendable, Equatable {
    case accessibilityNotTrusted
    case appNotRunning(appName: String)
    case noWindow(appName: String)
    case appNotResponding(appName: String)
    case screenRecordingNotAllowed
    case captureFailed(reason: String)

    /// One sentence for the popup, naming the fix when there is one.
    public var explanation: String {
        switch self {
        case .accessibilityNotTrusted:
            "Glim needs Accessibility permission (System Settings → Privacy & Security → Accessibility)."
        case .appNotRunning(let appName):
            "\(appName) isn't running."
        case .noWindow(let appName):
            "\(appName) has no open window."
        case .appNotResponding(let appName):
            "\(appName) isn't responding."
        case .screenRecordingNotAllowed:
            "Glim needs Screen Recording permission to look at this window."
        case .captureFailed(let reason):
            "Could not capture the window: \(reason)"
        }
    }
}
