import Carbon
import Testing

@testable import AutoClicker

/// Checks every literal in `VirtualKeyCode` against the Carbon constant it mirrors.
struct VirtualKeyCodeTests {
    @Test func namedKeysMirrorCarbon() {
        #expect(VirtualKeyCode.escape == UInt32(kVK_Escape))
        #expect(VirtualKeyCode.space == UInt32(kVK_Space))
        #expect(VirtualKeyCode.return == UInt32(kVK_Return))
        #expect(VirtualKeyCode.keypadEnter == UInt32(kVK_ANSI_KeypadEnter))
        #expect(VirtualKeyCode.tab == UInt32(kVK_Tab))
        #expect(VirtualKeyCode.delete == UInt32(kVK_Delete))
        #expect(VirtualKeyCode.forwardDelete == UInt32(kVK_ForwardDelete))
        #expect(VirtualKeyCode.leftArrow == UInt32(kVK_LeftArrow))
        #expect(VirtualKeyCode.rightArrow == UInt32(kVK_RightArrow))
        #expect(VirtualKeyCode.downArrow == UInt32(kVK_DownArrow))
        #expect(VirtualKeyCode.upArrow == UInt32(kVK_UpArrow))
        #expect(VirtualKeyCode.home == UInt32(kVK_Home))
        #expect(VirtualKeyCode.end == UInt32(kVK_End))
        #expect(VirtualKeyCode.pageUp == UInt32(kVK_PageUp))
        #expect(VirtualKeyCode.pageDown == UInt32(kVK_PageDown))
        #expect(VirtualKeyCode.help == UInt32(kVK_Help))
        #expect(VirtualKeyCode.f6 == UInt32(kVK_F6))
    }

    @Test func functionKeysMirrorCarbonInOrder() {
        let carbon = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ].map { UInt32($0) }
        #expect(VirtualKeyCode.functionKeys == carbon)
        #expect(VirtualKeyCode.functionKeyNumber(of: UInt32(kVK_F1)) == 1)
        #expect(VirtualKeyCode.functionKeyNumber(of: UInt32(kVK_F20)) == 20)
        #expect(VirtualKeyCode.functionKeyNumber(of: UInt32(kVK_ANSI_F)) == nil)
    }

    @Test func modifierKeysMirrorCarbon() {
        let carbon: Set<UInt32> = Set(
            [
                kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift, kVK_CapsLock, kVK_Option, kVK_RightOption,
                kVK_Control, kVK_RightControl, kVK_Function,
            ].map { UInt32($0) })
        #expect(VirtualKeyCode.modifierKeys == carbon)
        #expect(VirtualKeyCode.isModifierKey(UInt32(kVK_Shift)))
        #expect(!VirtualKeyCode.isModifierKey(UInt32(kVK_ANSI_A)))
    }

    @Test func characterKeysHaveNoFixedName() {
        #expect(VirtualKeyCode.fixedName(for: UInt32(kVK_ANSI_A)) == nil)
        #expect(VirtualKeyCode.fixedName(for: UInt32(kVK_ANSI_Semicolon)) == nil)
    }
}
