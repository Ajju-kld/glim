/// Why an allowed action could not be carried out.
public enum ExecutionError: Error, Sendable, Equatable {
    /// The kill switch tripped; nothing further runs.
    case stopped
    case appNotRunning(appName: String)
    case appDidNotOpen(appName: String, reason: String)
    case activationFailed(appName: String)
    case quitRefused(appName: String)
    case missingTarget
    /// The control changed after it was read, so Glim refused to act on it.
    case elementChanged(label: String, change: String)
    /// Keyboard focus is not on the chosen field, so typing was stopped.
    case focusNotOnTarget(label: String)
    case actionFailed(reason: String)
    case windowUnavailable(appName: String)
    case accessibility(ScreenReadingError)
    case unsupportedAction(ActionKind)
    case cannotCreateInputEvent
    /// The window moved or resized after the screenshot a click was found on.
    case windowMovedSinceCapture(appName: String)

    /// One sentence for the popup.
    public var explanation: String {
        switch self {
        case .stopped: "Glim was stopped."
        case .appNotRunning(let appName): "\(appName) isn't running."
        case .appDidNotOpen(let appName, let reason): "\(appName) didn't open: \(reason)"
        case .activationFailed(let appName): "Could not switch to \(appName)."
        case .quitRefused(let appName): "\(appName) did not quit."
        case .missingTarget: "No control was chosen for this step."
        case .elementChanged(let label, let change):
            "“\(label)” changed before Glim could act (\(change)), so it stopped."
        case .focusNotOnTarget(let label): "Typing stopped: the cursor left “\(label)”."
        case .actionFailed(let reason): "The action failed: \(reason)"
        case .windowUnavailable(let appName): "\(appName) has no window to arrange."
        case .accessibility(let readingError): readingError.explanation
        case .unsupportedAction(let kind): "“\(kind.displayName)” is not performed by the executor."
        case .cannotCreateInputEvent: "Could not create a keyboard, mouse or scroll event."
        case .windowMovedSinceCapture(let appName):
            "\(appName)'s window moved after Glim looked at it, so it didn't click."
        }
    }
}
