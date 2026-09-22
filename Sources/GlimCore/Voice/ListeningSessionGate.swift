/// Keeps push-to-talk honest when the talk key is released while the microphone is still
/// starting (permission prompts, the first model download): the start is cancelled instead of
/// turning the microphone on after the person let go.
struct ListeningSessionGate {
    enum Phase: Equatable {
        case idle
        case starting(session: Int)
        case listening(session: Int)
    }

    enum StopDisposition: Equatable {
        /// The microphone wasn't on yet; the start is abandoned.
        case cancelStart
        /// The microphone is on; stop it and finish recognition.
        case stopListening
        /// Nothing was starting or listening.
        case nothingToStop
    }

    private(set) var phase = Phase.idle
    private var latestSession = 0

    /// Starts a new session, superseding any earlier one.
    mutating func beginStarting() -> Int {
        latestSession += 1
        phase = .starting(session: latestSession)
        return latestSession
    }

    /// Whether `session` should keep starting after an `await`.
    func shouldContinueStarting(_ session: Int) -> Bool {
        phase == .starting(session: session)
    }

    /// Marks `session` as listening; false if it was cancelled or superseded meanwhile.
    mutating func finishStarting(_ session: Int) -> Bool {
        guard shouldContinueStarting(session) else {
            return false
        }
        phase = .listening(session: session)
        return true
    }

    /// The talk key was released.
    mutating func requestStop() -> StopDisposition {
        switch phase {
        case .starting:
            phase = .idle
            return .cancelStart
        case .listening:
            phase = .idle
            return .stopListening
        case .idle:
            return .nothingToStop
        }
    }

    /// Everything stops (kill switch).
    mutating func reset() {
        phase = .idle
    }
}
