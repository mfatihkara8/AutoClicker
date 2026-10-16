import os

/// Thread-safe list of values recorded from callbacks that run on other queues.
final class CallRecorder<Value: Sendable>: Sendable {
    private let recorded = OSAllocatedUnfairLock<[Value]>(initialState: [])

    /// All recorded values, oldest first.
    var values: [Value] {
        recorded.withLock { $0 }
    }

    /// The number of recorded values.
    var count: Int {
        recorded.withLock { $0.count }
    }

    /// Records `value` and returns the new count.
    @discardableResult
    func record(_ value: Value) -> Int {
        recorded.withLock { values in
            values.append(value)
            return values.count
        }
    }
}
