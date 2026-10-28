import Foundation
import Testing

@testable import AutoClicker

struct ClickModifiersTests {
    private static let all: ClickModifiers = [.shift, .control, .option, .command]

    private func encoded(_ modifiers: ClickModifiers) throws -> String {
        String(decoding: try JSONEncoder().encode(modifiers), as: UTF8.self)
    }

    private func decoded(_ json: String) throws -> ClickModifiers {
        try JSONDecoder().decode(ClickModifiers.self, from: Data(json.utf8))
    }

    // MARK: - Option set

    @Test func singleModifiersAreDistinct() {
        let singles: [ClickModifiers] = [.shift, .control, .option, .command]
        #expect(Set(singles).count == 4)
        #expect(singles.allSatisfy { !$0.isEmpty })
        #expect(singles.reduce(ClickModifiers()) { $0.union($1) } == Self.all)
    }

    @Test func menuOrderIsControlOptionShiftCommand() {
        #expect(ClickModifiers.menuOrder == [.control, .option, .shift, .command])
    }

    @Test func elementsInMenuOrderIgnoreInsertionOrder() {
        var modifiers = ClickModifiers()
        modifiers.insert(.command)
        modifiers.insert(.shift)
        modifiers.insert(.control)
        #expect(modifiers.elementsInMenuOrder == [.control, .shift, .command])
        #expect(ClickModifiers().elementsInMenuOrder.isEmpty)
    }

    // MARK: - Codable

    @Test func encodesNoModifiersAsAnEmptyArray() throws {
        #expect(try encoded([]) == "[]")
    }

    private static let encodings: [(ClickModifiers, String)] = [
        (.shift, #"["shift"]"#),
        (.control, #"["control"]"#),
        (.option, #"["option"]"#),
        (.command, #"["command"]"#),
        ([.shift, .command], #"["shift","command"]"#),
        ([.command, .control], #"["control","command"]"#),
        ([.shift, .control, .option, .command], #"["control","option","shift","command"]"#),
    ]

    @Test(arguments: encodings)
    func encodesStableNamesInMenuOrder(modifiers: ClickModifiers, json: String) throws {
        #expect(try encoded(modifiers) == json)
    }

    @Test(arguments: 0..<16)
    func roundTripsEveryCombination(rawValue: Int) throws {
        let modifiers = ClickModifiers(rawValue: rawValue)
        #expect(try decoded(try encoded(modifiers)) == modifiers)
    }

    @Test func decodesNamesInAnyOrderAndDuplicates() throws {
        #expect(try decoded(#"["command","shift","command"]"#) == [.shift, .command])
    }

    @Test func ignoresUnknownNames() throws {
        #expect(try decoded(#"["shift","fn","capsLock","SHIFT"]"#) == .shift)
        #expect(try decoded(#"["hyper"]"#).isEmpty)
    }

    @Test(arguments: [#""shift""#, "5", #"{"shift":true}"#, "[1]", "null"])
    func rejectsAnythingButAnArrayOfStrings(json: String) {
        #expect(throws: DecodingError.self) {
            try decoded(json)
        }
    }
}
