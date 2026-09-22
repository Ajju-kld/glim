/// Why an action waits for the person's click. Several reasons can apply at once; the
/// confirmation panel lists them all.
public enum ConfirmationReason: Sendable, Equatable {
    case riskyWord(matchedPhrase: String, elementLabel: String)
    case pressReturn
    case planMismatch(planned: String, chosen: String)
    case checkerDisagrees(checkerName: String, checkerChoice: String)
    case checkerOffline(checkerName: String)
    case supervisedApp(appName: String)
    case quitApp(appName: String)

    /// One sentence for the confirmation panel.
    public var explanation: String {
        switch self {
        case .riskyWord(let matchedPhrase, let elementLabel):
            "“\(elementLabel)” contains “\(matchedPhrase)”."
        case .pressReturn:
            "Pressing Return can send or submit."
        case .planMismatch(let planned, let chosen):
            "The plan said “\(planned)”, but the AI chose “\(chosen)”."
        case .checkerDisagrees(let checkerName, let checkerChoice):
            "\(checkerName) would choose “\(checkerChoice)” instead."
        case .checkerOffline(let checkerName):
            "\(checkerName) is offline, so every click and typing step asks you."
        case .supervisedApp(let appName):
            "\(appName) is supervised: every step asks you."
        case .quitApp(let appName):
            "Quitting \(appName) may close unsaved work."
        }
    }
}
