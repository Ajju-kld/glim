/// Why an action waits for the person's click. Several reasons can apply at once; the
/// confirmation panel lists them all.
public enum ConfirmationReason: Sendable, Equatable {
    case riskyWord(matchedPhrase: String, elementLabel: String)
    case pressReturn(activates: String?)
    case planMismatch(planned: String, chosen: String)
    case checkerDisagrees(checkerName: String, checkerChoice: String)
    case checkerOffline(checkerName: String)
    case supervisedApp(appName: String)
    case quitApp(appName: String)

    /// Whether this reason is a danger to the person — something that sends, submits or
    /// closes, or an app they chose to supervise. The others (a pick that differs from the plan's
    /// wording, a checker that disagrees or is offline) are doubts about the AI, not dangers;
    /// with ``SafetyPolicy/asksOnlyBeforeDangerousSteps`` on they don't ask.
    public var isDangerous: Bool {
        switch self {
        case .riskyWord, .pressReturn, .supervisedApp, .quitApp: true
        case .planMismatch, .checkerDisagrees, .checkerOffline: false
        }
    }

    /// One sentence for the confirmation panel.
    public var explanation: String {
        switch self {
        case .riskyWord(let matchedPhrase, let elementLabel):
            "“\(elementLabel)” contains “\(matchedPhrase)”."
        case .pressReturn(let activatedControl):
            activatedControl.map { "Pressing Return would activate “\($0)”." }
                ?? "Pressing Return can send or submit."
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
