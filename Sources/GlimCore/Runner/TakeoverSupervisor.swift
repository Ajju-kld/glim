import Synchronization

/// Runs the takeover monitor while Glim acts, and pauses it while a panel waits for the person
/// (their clicks on the panel must not count as taking over).
final class TakeoverSupervisor: Sendable {
    private let monitor: TakeoverMonitor?
    private let watchTask = Mutex<Task<Void, Never>?>(nil)

    init(monitor: TakeoverMonitor?) {
        self.monitor = monitor
    }

    func start() {
        guard let monitor else {
            return
        }
        let startInstant = ContinuousClock.now
        let newTask = Task { await monitor.watchUntilCancelled(from: startInstant) }
        let previousTask = watchTask.withLock { current in
            let previous = current
            current = newTask
            return previous
        }
        previousTask?.cancel()
    }

    func stop() {
        let runningTask = watchTask.withLock { current in
            let running = current
            current = nil
            return running
        }
        runningTask?.cancel()
    }
}
