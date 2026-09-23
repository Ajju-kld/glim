/// Carries out actions that the safety gate allowed.
public protocol ActionPerforming: Sendable {
    /// Performs `action`, re-checking the kill switch right before every operating-system call.
    func perform(_ action: ExecutableAction) async throws(ExecutionError)
}
