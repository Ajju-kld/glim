/// Reads again until a result is ready or time runs out.
///
/// A Chromium app builds its accessibility tree about two seconds after being woken, so the
/// first read of its window comes back empty.
enum ControlsWait {
    /// Calls `read` until `isReady` accepts its value or `deadline` passes, pausing `interval`
    /// between reads. Returns the last value read. Runs on the caller's actor, so `read` may
    /// touch its state.
    static func poll<Value, Failure: Error>(
        isolation: isolated (any Actor)? = #isolation,
        until deadline: ContinuousClock.Instant,
        every interval: Duration,
        read: () async throws(Failure) -> Value,
        isReady: (Value) -> Bool
    ) async throws(Failure) -> Value {
        var value = try await read()
        while !isReady(value), ContinuousClock.now + interval < deadline {
            do {
                try await Task.sleep(for: interval)
            } catch {
                // Cancelled: the task is ending, so the latest read is the answer.
                return value
            }
            value = try await read()
        }
        return value
    }
}
