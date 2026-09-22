/// What the notch pill shows. Status only — decisions happen in the centered panels (B-Q19).
public enum PillStatus: Sendable, Equatable {
    case hidden
    case listening(transcript: String, level: Float)
    case thinking
    case waitingForYou
    case acting(stepNumber: Int, totalSteps: Int, summary: String)
    case done(message: String)
    case stopped(reason: String)

    /// Whether the pill glows red.
    public var isAlert: Bool {
        if case .stopped = self { true } else { false }
    }

    /// The status after a live voice update.
    public func applying(_ voiceEvent: VoiceEvent) -> PillStatus {
        var transcript = ""
        var level: Float = 0
        if case .listening(let currentTranscript, let currentLevel) = self {
            transcript = currentTranscript
            level = currentLevel
        }
        switch voiceEvent {
        case .level(let newLevel): return .listening(transcript: transcript, level: newLevel)
        case .transcript(let newTranscript):
            return .listening(transcript: newTranscript, level: level)
        }
    }

    /// The status after a runner event.
    public func applying(_ taskEvent: TaskEvent) -> PillStatus {
        switch taskEvent {
        case .thinking:
            return .thinking
        case .awaitingPlanApproval, .awaitingConfirmation:
            return .waitingForYou
        case .acting(let stepNumber, let totalSteps, let summary):
            return .acting(stepNumber: stepNumber, totalSteps: totalSteps, summary: summary)
        case .finished(let outcome):
            return Self.status(for: outcome)
        }
    }

    private static func status(for outcome: TaskOutcome) -> PillStatus {
        switch outcome {
        case .completed: .done(message: "Done")
        case .answered: .done(message: "Answered")
        case .cancelled: .hidden
        case .stopped(let reason): .stopped(reason: reason.explanation)
        case .blocked(let violation, _): .stopped(reason: violation.title)
        case .failed(let message): .stopped(reason: message)
        }
    }
}
