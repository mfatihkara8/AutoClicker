/// Polls `condition` on the main actor every millisecond until it holds or `timeout` passes, and returns whether it
/// held.
///
/// The main-actor counterpart of `waitUntil(timeout:_:)`, for conditions on main-actor state such as a view model.
/// Each sleep yields the main actor, so the tasks under test keep running while the test waits.
@MainActor
func waitUntilOnMainActor(timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
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
