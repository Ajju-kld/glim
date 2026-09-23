/// Resumes a waiting decision exactly once — whichever comes first: a click, the timeout, or
/// the kill switch dismissing every panel.
@MainActor
final class PendingDecision {
    private var continuation: CheckedContinuation<Bool, Never>?
    private let onResolve: () -> Void

    init(continuation: CheckedContinuation<Bool, Never>, onResolve: @escaping () -> Void) {
        self.continuation = continuation
        self.onResolve = onResolve
    }

    var isResolved: Bool {
        continuation == nil
    }

    func resolve(_ answer: Bool) {
        guard let continuation else {
            return
        }
        self.continuation = nil
        continuation.resume(returning: answer)
        onResolve()
    }
}
