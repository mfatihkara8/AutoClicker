import Carbon
import Testing

@testable import AutoClicker

struct HotkeyTests {
    @Test func f6UsesTheCarbonKeyCodeWithoutModifiers() {
        #expect(Hotkey.f6.keyCode == UInt32(kVK_F6))
        #expect(Hotkey.f6.modifiers == 0)
    }

    @Test func escapeUsesTheCarbonKeyCodeWithoutModifiers() {
        #expect(Hotkey.escape.keyCode == UInt32(kVK_Escape))
        #expect(Hotkey.escape.modifiers == 0)
    }

    @Test func modifiersDefaultToNone() {
        #expect(Hotkey(keyCode: UInt32(kVK_F6)) == .f6)
    }

    @Test func modifiersTakePartInEquality() {
        let commandF6 = Hotkey(keyCode: UInt32(kVK_F6), modifiers: UInt32(cmdKey))
        #expect(commandF6 != .f6)
        #expect(Set([commandF6, .f6, .f6]).count == 2)
    }

    @Test func knownHotkeysHaveDisplayNames() {
        #expect(Hotkey.f6.displayName == "F6")
        #expect(Hotkey.escape.displayName == "Esc")
    }

    @Test func unknownHotkeyFallsBackToItsKeyCode() {
        #expect(Hotkey(keyCode: 42).displayName == "Key 42")
    }
}
