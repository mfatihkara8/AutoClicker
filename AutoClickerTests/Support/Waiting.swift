import Dispatch

/// Polls `condition` every millisecond until it holds or `timeout` passes, and returns whether it held.
///
/// Lets timer-driven tests wait exactly as long as needed instead of sleeping for a fixed, pessimistic time.
func waitUntil(timeout: Duration = .seconds(5), _ condition: @Sendable () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        guard clock.now < deadline else {
            return false
        }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}

/// Waits until every block already submitted to the serial `queue` has run.
func drain(_ queue: DispatchQueue) async {
    await withCheckedContinuation { continuation in
        queue.async {
            continuation.resume()
        }
    }
}
