import CoreGraphics
import Foundation
import Testing

@testable import AutoClicker

struct ClickPointTests {
    private static func sortedJSON(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    // MARK: - Delay

    @Test func delayRangeIsOneMillisecondToOneDay() {
        #expect(ClickPoint.delayRange == 1...86_400_000)
        #expect(ClickPoint.delayRange.upperBound == 24 * 60 * 60 * 1_000)
    }

    @Test(arguments: [
        (1, Duration.milliseconds(1)),
        (250, .milliseconds(250)),
        (86_400_000, .seconds(86_400)),
    ])
    func delayIsTheStoredMilliseconds(milliseconds: Int, expected: Duration) {
        #expect(ClickPoint(point: .zero, delayMilliseconds: milliseconds).delay == expected)
    }

    @Test(arguments: [
        (0, Duration.milliseconds(1)),
        (-5, .milliseconds(1)),
        (86_400_001, .seconds(86_400)),
        (Int.max, .seconds(86_400)),
    ])
    func delayIsClampedToTheRange(milliseconds: Int, expected: Duration) {
        let point = ClickPoint(point: .zero, delayMilliseconds: milliseconds)
        #expect(point.delay == expected)
        // The stored value stays as entered.
        #expect(point.delayMilliseconds == milliseconds)
    }

    // MARK: - Coding

    @Test func encodesFlatJSON() throws {
        let point = ClickPoint(point: CGPoint(x: -1_440.5, y: 20), delayMilliseconds: 750)
        #expect(try Self.sortedJSON(point) == #"{"delayMilliseconds":750,"x":-1440.5,"y":20}"#)
    }

    @Test func codableRoundTrip() throws {
        let point = ClickPoint(point: CGPoint(x: 12.25, y: -3), delayMilliseconds: 86_400_000)
        let data = try JSONEncoder().encode(point)
        #expect(try JSONDecoder().decode(ClickPoint.self, from: data) == point)
    }

    @Test(arguments: [
        #"{"x":1,"y":2}"#,
        #"{"x":1,"delayMilliseconds":5}"#,
        #"{"y":2,"delayMilliseconds":5}"#,
        #"{"x":1,"y":2,"delayMilliseconds":"5"}"#,
    ])
    func rejectsAnIncompletePoint(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ClickPoint.self, from: Data(json.utf8))
        }
    }

    // MARK: - Sequence target

    @Test func sequenceHoldsAtMostFiftyPoints() {
        #expect(ClickTarget.maxSequencePoints == 50)
    }

    @Test func sequenceEncodesStableJSONShape() throws {
        let target = ClickTarget.sequence([
            ClickPoint(point: CGPoint(x: 10, y: 20), delayMilliseconds: 100),
            ClickPoint(point: CGPoint(x: -5.5, y: 0), delayMilliseconds: 2_000),
        ])
        #expect(
            try Self.sortedJSON(target)
                == #"{"kind":"sequence","points":[{"delayMilliseconds":100,"x":10,"y":20},"#
                + #"{"delayMilliseconds":2000,"x":-5.5,"y":0}]}"#)
    }

    @Test func emptySequenceEncodesAnEmptyList() throws {
        #expect(try Self.sortedJSON(ClickTarget.sequence([])) == #"{"kind":"sequence","points":[]}"#)
    }

    @Test(arguments: [
        ClickTarget.sequence([]),
        .sequence([ClickPoint(point: CGPoint(x: 1, y: 2), delayMilliseconds: 1)]),
        .sequence(
            (0..<ClickTarget.maxSequencePoints).map {
                ClickPoint(point: CGPoint(x: $0, y: -$0), delayMilliseconds: $0 + 1)
            }),
    ])
    func sequenceRoundTrips(target: ClickTarget) throws {
        let data = try JSONEncoder().encode(target)
        #expect(try JSONDecoder().decode(ClickTarget.self, from: data) == target)
    }

    @Test func decodesAPersistedSequence() throws {
        let json = #"{"kind":"sequence","points":[{"x":640,"y":400,"delayMilliseconds":500}]}"#
        let target = try JSONDecoder().decode(ClickTarget.self, from: Data(json.utf8))
        #expect(target == .sequence([ClickPoint(point: CGPoint(x: 640, y: 400), delayMilliseconds: 500)]))
    }

    @Test func decodingKeepsOnlyTheFirstFiftyPoints() throws {
        let points = (0..<60).map { ClickPoint(point: CGPoint(x: $0, y: 0), delayMilliseconds: 10) }
        let data = try JSONEncoder().encode(ClickTarget.sequence(points))
        let decoded = try JSONDecoder().decode(ClickTarget.self, from: data)
        #expect(decoded == .sequence(Array(points.prefix(50))))
    }

    @Test(arguments: [
        #"{"kind":"sequence"}"#,
        #"{"kind":"sequence","points":{}}"#,
        #"{"kind":"sequence","points":[{"x":1,"y":2}]}"#,
    ])
    func rejectsAMalformedSequence(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ClickTarget.self, from: Data(json.utf8))
        }
    }
}
