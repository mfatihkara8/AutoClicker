import os

/// Thread-safe total click counter shared between the engine and the UI.
///
/// The engine increments it on its serial click queue while the view model samples
/// `value` from the main actor at 10–20 Hz. A lock is used instead of
/// `Synchronization.Atomic`, which requires macOS 15 (see SPEC section 4).
final class ClickCounter: Sendable {
    private let count = OSAllocatedUnfairLock(initialState: 0)

    /// The current number of clicks.
    var value: Int {
        count.withLock { $0 }
    }

    /// Adds one click and returns the new total.
    ///
    /// The returned value is read under the same lock as the increment, so the engine can
    /// use it for its stop check without a second, possibly stale read.
    @discardableResult
    func increment() -> Int {
        count.withLock { value in
            value += 1
            return value
        }
    }

    /// Sets the counter back to zero.
    func reset() {
        count.withLock { $0 = 0 }
    }
}
