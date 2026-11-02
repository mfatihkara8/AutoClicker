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
        #expect(config.modifiers.isEmpty)
        #expect(config.positionOffset == 0)
    }

    @Test func positionOffsetRangeIsZeroTo200Points() {
        #expect(ClickConfiguration.positionOffsetRange == 0...200)
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
            stopCondition: .afterDuration(.seconds(30)),
            modifiers: [.control, .option, .shift, .command]),
        ClickConfiguration(
            clickType: .right,
            interval: ClickInterval(milliseconds: 250, jitterMilliseconds: 10),
            target: .sequence([
                ClickPoint(point: CGPoint(x: 10, y: 20), delayMilliseconds: 100),
                ClickPoint(point: CGPoint(x: 30, y: -40), delayMilliseconds: 86_400_000),
            ]),
            stopCondition: .afterClicks(9),
            positionOffset: 200),
    ])
    func codableRoundTrip(config: ClickConfiguration) throws {
        let data = try JSONEncoder().encode(config)
        #expect(try JSONDecoder().decode(ClickConfiguration.self, from: data) == config)
    }

    @Test func encodesStableTopLevelKeys() throws {
        let data = try JSONEncoder().encode(ClickConfiguration.default)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(
            Set(object.keys) == ["clickType", "interval", "target", "stopCondition", "modifiers", "positionOffset"])
        #expect(object["clickType"] as? String == "left")
        #expect(object["modifiers"] as? [String] == [])
        #expect(object["positionOffset"] as? Int == 0)
    }

    @Test(arguments: [0, 1, 37, 200])
    func positionOffsetRoundTrips(offset: Int) throws {
        var config = ClickConfiguration.default
        config.target = .fixed(CGPoint(x: 5, y: 5))
        config.positionOffset = offset
        let data = try JSONEncoder().encode(config)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["positionOffset"] as? Int == offset)
        #expect(try JSONDecoder().decode(ClickConfiguration.self, from: data) == config)
    }

    @Test func decodesAPersistedPayload() throws {
        let json = """
            {
              "clickType": "right",
              "interval": {"hours": 0, "minutes": 0, "seconds": 1, "milliseconds": 500, "jitterMilliseconds": 10},
              "target": {"kind": "fixed", "x": 10, "y": 20},
              "stopCondition": {"kind": "afterClicks", "clicks": 5},
              "modifiers": ["command", "shift"],
              "positionOffset": 12
            }
            """
        let config = try JSONDecoder().decode(ClickConfiguration.self, from: Data(json.utf8))
        #expect(
            config
                == ClickConfiguration(
                    clickType: .right,
                    interval: ClickInterval(seconds: 1, milliseconds: 500, jitterMilliseconds: 10),
                    target: .fixed(CGPoint(x: 10, y: 20)),
                    stopCondition: .afterClicks(5),
                    modifiers: [.shift, .command],
                    positionOffset: 12))
    }

    @Test func rejectsAPayloadWithoutModifiers() {
        // Older payloads without modifiers are migrated by `SettingsStore`; the configuration itself does not guess.
        let json = """
            {
              "clickType": "left",
              "interval": {"hours": 0, "minutes": 0, "seconds": 1, "milliseconds": 0, "jitterMilliseconds": 0},
              "target": {"kind": "currentCursor"},
              "stopCondition": {"kind": "never"},
              "positionOffset": 0
            }
            """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ClickConfiguration.self, from: Data(json.utf8))
        }
    }

    @Test func rejectsAPayloadWithoutPositionOffset() {
        // Version 3 payloads without the offset are migrated by `SettingsStore`; the configuration does not guess.
        let json = """
            {
              "clickType": "left",
              "interval": {"hours": 0, "minutes": 0, "seconds": 1, "milliseconds": 0, "jitterMilliseconds": 0},
              "target": {"kind": "currentCursor"},
              "stopCondition": {"kind": "never"},
              "modifiers": []
            }
            """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ClickConfiguration.self, from: Data(json.utf8))
        }
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
