import Carbon
import Foundation
import Testing

@testable import AutoClicker

struct HotkeyTests {
    private static let controlOption = UInt32(controlKey | optionKey)

    // MARK: - Constants

    @Test func f6UsesTheCarbonKeyCodeWithoutModifiers() {
        #expect(Hotkey.f6.keyCode == UInt32(kVK_F6))
        #expect(Hotkey.f6.modifiers == 0)
    }

    @Test func escapeUsesTheCarbonKeyCodeWithoutModifiers() {
        #expect(Hotkey.escape.keyCode == UInt32(kVK_Escape))
        #expect(Hotkey.escape.modifiers == 0)
    }

    @Test func modifierLiteralsMirrorCarbon() {
        #expect(Hotkey.Modifier.command == UInt32(cmdKey))
        #expect(Hotkey.Modifier.shift == UInt32(shiftKey))
        #expect(Hotkey.Modifier.option == UInt32(optionKey))
        #expect(Hotkey.Modifier.control == UInt32(controlKey))
    }

    // MARK: - Identity

    @Test func modifiersDefaultToNone() {
        #expect(Hotkey(keyCode: UInt32(kVK_F6)) == .f6)
    }

    @Test func modifiersTakePartInEquality() {
        let commandF6 = Hotkey(keyCode: UInt32(kVK_F6), modifiers: UInt32(cmdKey))
        #expect(commandF6 != .f6)
        #expect(Set([commandF6, .f6, .f6]).count == 2)
    }

    @Test func keyLabelDoesNotTakePartInEqualityOrHashing() {
        let latin = Hotkey(keyCode: UInt32(kVK_ANSI_I), modifiers: Self.controlOption, keyLabel: "I")
        let turkish = Hotkey(keyCode: UInt32(kVK_ANSI_I), modifiers: Self.controlOption, keyLabel: "İ")
        let unlabeled = Hotkey(keyCode: UInt32(kVK_ANSI_I), modifiers: Self.controlOption)
        #expect(latin == turkish)
        #expect(latin == unlabeled)
        #expect(Set([latin, turkish, unlabeled]).count == 1)
        #expect([latin: 1][turkish] == 1)
    }

    // MARK: - Display names

    @Test func knownHotkeysHaveDisplayNames() {
        #expect(Hotkey.f6.displayName == "F6")
        #expect(Hotkey.escape.displayName == "Esc")
    }

    @Test func unknownHotkeyFallsBackToItsKeyCode() {
        #expect(Hotkey(keyCode: 42).displayName == "Key 42")
    }

    @Test func emptyLabelFallsBackToTheKeyCode() {
        #expect(Hotkey(keyCode: 42, modifiers: UInt32(cmdKey), keyLabel: "").displayName == "⌘Key 42")
    }

    @Test func modifierGlyphsFollowTheMacOSOrder() {
        let all = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        #expect(Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: all, keyLabel: "K").displayName == "⌃⌥⇧⌘K")
        #expect(
            Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | controlKey), keyLabel: "K").displayName
                == "⌃⌘K")
        #expect(
            Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(shiftKey | optionKey), keyLabel: "K").displayName
                == "⌥⇧K")
    }

    @Test func characterKeysShowTheRecordedLabel() {
        #expect(
            Hotkey(keyCode: UInt32(kVK_ANSI_Semicolon), modifiers: Self.controlOption, keyLabel: "Ş").displayName
                == "⌃⌥Ş")
        #expect(Hotkey(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey), keyLabel: "1").displayName == "⌘1")
    }

    @Test func fixedNamesWinOverARecordedLabel() {
        // The recorder may capture a control character for keys such as Return; the fixed name is what users expect.
        #expect(Hotkey(keyCode: UInt32(kVK_Return), modifiers: UInt32(cmdKey), keyLabel: "\r").displayName == "⌘Return")
    }

    @Test(arguments: 1...20)
    func functionKeysAreNamedByNumber(number: Int) {
        let keyCode = VirtualKeyCode.functionKeys[number - 1]
        #expect(Hotkey(keyCode: keyCode).displayName == "F\(number)")
    }

    @Test(arguments: [
        (kVK_Space, "Space"),
        (kVK_Return, "Return"),
        (kVK_ANSI_KeypadEnter, "Enter"),
        (kVK_Tab, "Tab"),
        (kVK_Delete, "Delete"),
        (kVK_ForwardDelete, "Forward Delete"),
        (kVK_LeftArrow, "←"),
        (kVK_RightArrow, "→"),
        (kVK_UpArrow, "↑"),
        (kVK_DownArrow, "↓"),
        (kVK_Home, "Home"),
        (kVK_End, "End"),
        (kVK_PageUp, "Page Up"),
        (kVK_PageDown, "Page Down"),
        (kVK_Escape, "Esc"),
    ])
    func namedKeysHaveFixedNames(keyCode: Int, name: String) {
        #expect(Hotkey(keyCode: UInt32(keyCode), modifiers: UInt32(cmdKey)).displayName == "⌘" + name)
    }

    // MARK: - Coding

    @Test func encodesWithStableKeys() throws {
        let hotkey = Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: Self.controlOption, keyLabel: "K")
        let data = try JSONEncoder().encode(hotkey)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["keyCode", "modifiers", "keyLabel"])
        #expect(object["keyCode"] as? Int == kVK_ANSI_K)
        #expect(object["modifiers"] as? Int == controlKey | optionKey)
        #expect(object["keyLabel"] as? String == "K")
    }

    @Test func omitsAMissingLabel() throws {
        let data = try JSONEncoder().encode(Hotkey.f6)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["keyCode", "modifiers"])
    }

    @Test func decodesALiteralWithAndWithoutALabel() throws {
        let labeled = try JSONDecoder().decode(
            Hotkey.self, from: Data(#"{"keyCode":41,"modifiers":256,"keyLabel":"Ş"}"#.utf8))
        #expect(labeled == Hotkey(keyCode: UInt32(kVK_ANSI_Semicolon), modifiers: UInt32(cmdKey)))
        #expect(labeled.keyLabel == "Ş")

        let unlabeled = try JSONDecoder().decode(Hotkey.self, from: Data(#"{"keyCode":97,"modifiers":0}"#.utf8))
        #expect(unlabeled == .f6)
        #expect(unlabeled.keyLabel == nil)
    }

    @Test func rejectsAHotkeyWithoutAKeyCode() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Hotkey.self, from: Data(#"{"modifiers":0}"#.utf8))
        }
    }
}
