/// How the notch orb behaves in each pill state.
public enum OrbMood: Sendable, Equatable {
    /// Listening: the torus swells and thickens with the voice level (0…1).
    case listening(level: Double)
    /// Planning: the torus spins fast and springs on every beat.
    case thinking
    /// Carrying out a step: spins and springs more gently.
    case acting
    /// Waiting for the person in a panel: breathes slowly.
    case waiting
    /// Finished: still, then the pill shrinks back into the notch.
    case done
    /// Stopped or blocked: still, in red.
    case alert
}

extension PillStatus {
    /// The orb's mood for this status; nil when the pill is hidden.
    public var orbMood: OrbMood? {
        switch self {
        case .hidden: nil
        case .listening(_, let level): .listening(level: Double(level))
        case .thinking: .thinking
        case .waitingForYou: .waiting
        case .acting: .acting
        case .done: .done
        case .stopped: .alert
        }
    }
}

extension PillStatus {
    /// Whether the pill shows ■ to stop: only while Glim is working on a request. At other
    /// times the pill lets every click pass through to the app below.
    public var offersStop: Bool {
        switch self {
        case .thinking, .waitingForYou, .acting: true
        case .hidden, .listening, .done, .stopped: false
        }
    }
}
