import Foundation
import Testing

@testable import AutoClicker

struct StopConditionTests {
    @Test(arguments: [0, 1, 1_000, Int.max])
    func neverIsNeverSatisfied(clicks: Int) {
        #expect(!StopCondition.never.isSatisfied(clicks: clicks, elapsed: .seconds(clicks)))
    }

    @Test func afterClicksBoundary() {
        let condition = StopCondition.afterClicks(10)
        #expect(!condition.isSatisfied(clicks: 9, elapsed: .zero))
        #expect(condition.isSatisfied(clicks: 10, elapsed: .zero))
        #expect(condition.isSatisfied(clicks: 11, elapsed: .zero))
    }

    @Test func afterClicksIgnoresElapsedTime() {
        #expect(!StopCondition.afterClicks(5).isSatisfied(clicks: 4, elapsed: .seconds(3_600)))
    }

    @Test func afterOneClickIsSatisfiedAfterTheFirstClick() {
        let condition = StopCondition.afterClicks(1)
        #expect(!condition.isSatisfied(clicks: 0, elapsed: .zero))
        #expect(condition.isSatisfied(clicks: 1, elapsed: .zero))
    }

    @Test(arguments: [0, -1, Int.min])
    func afterNonPositiveClicksIsSatisfiedImmediately(limit: Int) {
        #expect(StopCondition.afterClicks(limit).isSatisfied(clicks: 0, elapsed: .zero))
    }

    @Test func afterDurationBoundary() {
        let condition = StopCondition.afterDuration(.seconds(5))
        #expect(!condition.isSatisfied(clicks: 0, elapsed: .seconds(5) - .nanoseconds(1)))
        #expect(condition.isSatisfied(clicks: 0, elapsed: .seconds(5)))
        #expect(condition.isSatisfied(clicks: 0, elapsed: .seconds(5) + .nanoseconds(1)))
    }

    @Test func afterDurationIgnoresClickCount() {
        #expect(!StopCondition.afterDuration(.seconds(1)).isSatisfied(clicks: 1_000_000, elapsed: .milliseconds(999)))
    }

    @Test(arguments: [Duration.zero, .milliseconds(-1), .seconds(-60)])
    func afterNonPositiveDurationIsSatisfiedImmediately(limit: Duration) {
        #expect(StopCondition.afterDuration(limit).isSatisfied(clicks: 0, elapsed: .zero))
    }

    @Test(arguments: [
        StopCondition.never,
        .afterClicks(0),
        .afterClicks(250),
        .afterDuration(.zero),
        .afterDuration(.seconds(90)),
        .afterDuration(.milliseconds(1_500)),
        .afterDuration(.nanoseconds(7)),
    ])
    func codableRoundTrip(condition: StopCondition) throws {
        let data = try JSONEncoder().encode(condition)
        #expect(try JSONDecoder().decode(StopCondition.self, from: data) == condition)
    }

    @Test func encodesStableJSONShape() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let never = try encoder.encode(StopCondition.never)
        let clicks = try encoder.encode(StopCondition.afterClicks(3))
        let duration = try encoder.encode(StopCondition.afterDuration(.milliseconds(2_500)))
        #expect(String(decoding: never, as: UTF8.self) == #"{"kind":"never"}"#)
        #expect(String(decoding: clicks, as: UTF8.self) == #"{"clicks":3,"kind":"afterClicks"}"#)
        #expect(
            String(decoding: duration, as: UTF8.self)
                == #"{"attoseconds":500000000000000000,"kind":"afterDuration","seconds":2}"#)
    }

    @Test func decodingUnknownKindThrows() {
        let data = Data(#"{"kind":"afterLunch"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(StopCondition.self, from: data)
        }
    }
}
