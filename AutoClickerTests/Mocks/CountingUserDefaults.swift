import Foundation
import os

/// A `UserDefaults` suite that counts writes, so tests can check how often the settings are saved.
///
/// Create it with `init?(suiteName:)` on a `TestDefaultsSuite` name and remove the suite with `TestDefaultsSuite` when done.
final class CountingUserDefaults: UserDefaults {
    // A lock rather than a plain `var`, because `UserDefaults` may be used from any thread.
    private let writes = OSAllocatedUnfairLock(initialState: 0)

    /// The number of `set(_:forKey:)` calls so far.
    var setCallCount: Int {
        writes.withLock { $0 }
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        writes.withLock { $0 += 1 }
        super.set(value, forKey: defaultName)
    }
}
