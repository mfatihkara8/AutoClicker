import Foundation
import Testing

@testable import AutoClicker

struct ClickIntervalTests {
    @Test func combinesAllComponents() {
        let interval = ClickInterval(hours: 1, minutes: 2, seconds: 3, milliseconds: 4)
        #expect(interval.duration == .milliseconds(3_723_004))
    }

    @Test func zeroIntervalClampsToOneMillisecond() {
        #expect(ClickInterval().duration == .milliseconds(1))
    }

    @Test func oneMillisecondIsKept() {
        #expect(ClickInterval(milliseconds: 1).duration == .milliseconds(1))
    }

    @Test func negativeComponentsAreIgnored() {
        #expect(ClickInterval(seconds: 1, milliseconds: -500).duration == .seconds(1))
        #expect(ClickInterval(hours: -1, minutes: -1, seconds: -1, milliseconds: -1).duration == .milliseconds(1))
    }

    @Test func hugeComponentsSaturateInsteadOfOverflowing() {
        let interval = ClickInterval(hours: Int.max, minutes: Int.max, seconds: Int.max, milliseconds: Int.max)
        #expect(interval.totalMilliseconds == Int.max)
        #expect(interval.duration == .milliseconds(Int.max))
    }

    @Test func jitterIsZeroWhenDisabled() {
        var generator = SeededGenerator(seed: 1)
        let interval = ClickInterval(milliseconds: 100)
        for _ in 0..<100 {
            #expect(interval.jitterOffset(using: &generator) == .zero)
        }
    }

    @Test func jitterStaysWithinRequestedBounds() {
        var generator = SeededGenerator(seed: 42)
        let interval = ClickInterval(milliseconds: 1_000, jitterMilliseconds: 50)
        #expect(interval.effectiveJitterMilliseconds == 50)
        var sawNegative = false
        var sawPositive = false
        for _ in 0..<1_000 {
            let offset = interval.jitterOffset(using: &generator)
            #expect(offset >= .milliseconds(-50) && offset <= .milliseconds(50))
            sawNegative = sawNegative || offset < .zero
            sawPositive = sawPositive || offset > .zero
        }
        #expect(sawNegative && sawPositive)
    }

    @Test func jitterIsDeterministicForTheSameSeed() {
        let interval = ClickInterval(milliseconds: 500, jitterMilliseconds: 100)
        var first = SeededGenerator(seed: 7)
        var second = SeededGenerator(seed: 7)
        let a = (0..<20).map { _ in interval.jitterOffset(using: &first) }
        let b = (0..<20).map { _ in interval.jitterOffset(using: &second) }
        #expect(a == b)
    }

    @Test func jitterIsCappedSoConsecutiveDeadlinesStayAtLeastOneMillisecondApart() {
        // 10 ms interval with ±1 s jitter: the cap is (10 - 1) / 2 = 4 ms.
        let interval = ClickInterval(milliseconds: 10, jitterMilliseconds: 1_000)
        #expect(interval.effectiveJitterMilliseconds == 4)
        var generator = SeededGenerator(seed: 3)
        var previous = interval.jitterOffset(using: &generator)
        for _ in 0..<1_000 {
            let next = interval.jitterOffset(using: &generator)
            // Gap between deadline n and n + 1 when offsets are applied to absolute deadlines.
            #expect(interval.duration + next - previous >= .milliseconds(1))
            previous = next
        }
    }

    @Test func jitterIsDisabledAtTheMinimumInterval() {
        let interval = ClickInterval(milliseconds: 1, jitterMilliseconds: 10)
        #expect(interval.effectiveJitterMilliseconds == 0)
    }

    @Test func negativeJitterIsTreatedAsZero() {
        #expect(ClickInterval(milliseconds: 100, jitterMilliseconds: -20).effectiveJitterMilliseconds == 0)
    }

    @Test func codableRoundTrip() throws {
        let interval = ClickInterval(hours: 1, minutes: 30, seconds: 15, milliseconds: 250, jitterMilliseconds: 20)
        let data = try JSONEncoder().encode(interval)
        #expect(try JSONDecoder().decode(ClickInterval.self, from: data) == interval)
    }

    @Test func encodesStableKeys() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(
            ClickInterval(hours: 1, minutes: 2, seconds: 3, milliseconds: 4, jitterMilliseconds: 5))
        #expect(
            String(decoding: data, as: UTF8.self)
                == #"{"hours":1,"jitterMilliseconds":5,"milliseconds":4,"minutes":2,"seconds":3}"#)
    }
}

/// Deterministic SplitMix64 generator so jitter tests are reproducible.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
