/// Internal control flow: the reasons a request ends early, thrown by the runner's steps and
/// turned into a ``TaskOutcome`` at the top.
enum RunnerStop: Error {
    case blocked(GuardViolation, stepNumber: Int?)
    case stopped(TripReason)
    case cancelled
    case failed(String)

    var outcome: TaskOutcome {
        switch self {
        case .blocked(let violation, let stepNumber): .blocked(violation, stepNumber: stepNumber)
        case .stopped(let reason): .stopped(reason)
        case .cancelled: .cancelled
        case .failed(let message): .failed(message)
        }
    }
}
