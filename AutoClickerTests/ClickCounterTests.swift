import Foundation
import Testing
import os

@testable import AutoClicker

struct ClickCounterTests {
    @Test func startsAtZero() {
        let counter = ClickCounter()
        #expect(counter.value == 0)
    }

    @Test func incrementReturnsNewValue() {
        let counter = ClickCounter()
        #expect(counter.increment() == 1)
        #expect(counter.increment() == 2)
        #expect(counter.value == 2)
    }

    @Test func resetSetsValueBackToZero() {
        let counter = ClickCounter()
        for _ in 0..<5 {
            counter.increment()
        }
        counter.reset()
        #expect(counter.value == 0)
        #expect(counter.increment() == 1)
    }

    @Test func concurrentIncrementsGiveExactCount() {
        let counter = ClickCounter()
        let iterations = 10_000
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            counter.increment()
        }
        #expect(counter.value == iterations)
    }

    /// Every caller must see a distinct new value, so the engine can rely on the
    /// returned value for its stop check without a second, racy read.
    @Test func concurrentIncrementsReturnDistinctValues() {
        let counter = ClickCounter()
        let iterations = 10_000
        let seen = OSAllocatedUnfairLock(initialState: Set<Int>())
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let newValue = counter.increment()
            seen.withLock { values in
                _ = values.insert(newValue)
            }
        }
        #expect(seen.withLock { $0 } == Set(1...iterations))
    }
}
