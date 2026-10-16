import CoreGraphics
import Foundation
import Testing

@testable import AutoClicker

struct ClickConfigurationTests {
    @Test func defaultIsLeftEvery100MillisecondsAtTheCursorForever() {
        let config = ClickConfiguration.default
        #expect(config.clickType == .left)
        #expect(config.interval.duration == .milliseconds(100))
        #expect(config.interval.jitterMilliseconds == 0)
        #expect(config.target == .currentCursor)
        #expect(config.stopCondition == .never)
    }

    @Test(arguments: [
        ClickConfiguration.default,
        ClickConfiguration(
            clickType: .double,
            interval: ClickInterval(minutes: 1, milliseconds: 5, jitterMilliseconds: 3),
            target: .fixed(CGPoint(x: -1_440.5, y: 200)),
            stopCondition: .afterClicks(42)),
        ClickConfiguration(
            clickType: .middle,
            interval: ClickInterval(seconds: 2),
            target: .currentCursor,
            stopCondition: .afterDuration(.seconds(30))),
    ])
    func codableRoundTrip(config: ClickConfiguration) throws {
        let data = try JSONEncoder().encode(config)
        #expect(try JSONDecoder().decode(ClickConfiguration.self, from: data) == config)
    }

    @Test func encodesStableTopLevelKeys() throws {
        let data = try JSONEncoder().encode(ClickConfiguration.default)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["clickType", "interval", "target", "stopCondition"])
        #expect(object["clickType"] as? String == "left")
    }

    @Test func decodesAPersistedPayload() throws {
        let json = """
            {
              "clickType": "right",
              "interval": {"hours": 0, "minutes": 0, "seconds": 1, "milliseconds": 500, "jitterMilliseconds": 10},
              "target": {"kind": "fixed", "x": 10, "y": 20},
              "stopCondition": {"kind": "afterClicks", "clicks": 5}
            }
            """
        let config = try JSONDecoder().decode(ClickConfiguration.self, from: Data(json.utf8))
        #expect(
            config
                == ClickConfiguration(
                    clickType: .right,
                    interval: ClickInterval(seconds: 1, milliseconds: 500, jitterMilliseconds: 10),
                    target: .fixed(CGPoint(x: 10, y: 20)),
                    stopCondition: .afterClicks(5)))
    }

    @Test(arguments: ClickType.allCases)
    func clickTypeEncodesAsItsRawValue(type: ClickType) throws {
        let data = try JSONEncoder().encode(type)
        #expect(String(decoding: data, as: UTF8.self) == "\"\(type.rawValue)\"")
    }

    @Test func clickTargetEncodesStableJSONShape() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let cursor = try encoder.encode(ClickTarget.currentCursor)
        let fixed = try encoder.encode(ClickTarget.fixed(CGPoint(x: 1.5, y: -2)))
        #expect(String(decoding: cursor, as: UTF8.self) == #"{"kind":"currentCursor"}"#)
        #expect(String(decoding: fixed, as: UTF8.self) == #"{"kind":"fixed","x":1.5,"y":-2}"#)
    }

    @Test func clickTargetRejectsUnknownKind() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ClickTarget.self, from: Data(#"{"kind":"window"}"#.utf8))
        }
    }
}
