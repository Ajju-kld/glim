/// What tripped the kill switch; shown in the guard popup and written to the audit log.
public enum TripReason: String, Sendable, Equatable, Codable {
    case killHotkey
    case stopButton
    case spokenStop
    case panelCancelled
    case humanTookOver

    /// One sentence for the guard popup.
    public var explanation: String {
        switch self {
        case .killHotkey: "You pressed ⌃⌥⌘K."
        case .stopButton: "You clicked STOP."
        case .spokenStop: "You said “stop”."
        case .panelCancelled: "You cancelled in a Glim panel."
        case .humanTookOver: "You took over the keyboard or mouse."
        }
    }
}
