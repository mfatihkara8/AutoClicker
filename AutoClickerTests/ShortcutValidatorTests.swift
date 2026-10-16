import AppKit
import Carbon
import Testing

@testable import AutoClicker

struct ShortcutValidatorTests {
    private static let english = Locale(identifier: "en_US")
    private static let turkish = Locale(identifier: "tr_TR")

    private func validate(_ keyCode: Int, _ modifiers: Int = 0, _ characters: String? = nil)
        -> ShortcutValidator.Outcome
    {
        ShortcutValidator.validate(
            RecordedKey(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers), characters: characters),
            locale: Self.english)
    }

    // MARK: - Function keys

    @Test(arguments: VirtualKeyCode.functionKeys)
    func functionKeysAreAcceptedAlone(keyCode: UInt32) {
        #expect(validate(Int(keyCode)) == .accepted(Hotkey(keyCode: keyCode)))
    }

    @Test(arguments: [shiftKey, cmdKey, optionKey | controlKey, cmdKey | shiftKey | optionKey | controlKey])
    func functionKeysAreAcceptedWithAnyModifiers(modifiers: Int) {
        #expect(validate(kVK_F6, modifiers) == .accepted(Hotkey(keyCode: UInt32(kVK_F6), modifiers: UInt32(modifiers))))
    }

    @Test func functionKeysGetNoLabel() throws {
        guard case .accepted(let hotkey) = validate(kVK_F13, 0, "\u{F710}") else {
            Issue.record("F13 must be accepted")
            return
        }
        #expect(hotkey.keyLabel == nil)
        #expect(hotkey.displayName == "F13")
    }

    // MARK: - Other keys need ⌘, ⌥ or ⌃

    @Test(arguments: [cmdKey, optionKey, controlKey, cmdKey | shiftKey, optionKey | shiftKey, controlKey | optionKey])
    func characterKeysAreAcceptedWithCommandOptionOrControl(modifiers: Int) throws {
        let outcome = validate(kVK_ANSI_K, modifiers, "k")
        #expect(outcome == .accepted(Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(modifiers))))
        guard case .accepted(let hotkey) = outcome else { return }
        #expect(hotkey.keyLabel == "K")
    }

    @Test(arguments: [kVK_Space, kVK_Return, kVK_Tab, kVK_Delete, kVK_LeftArrow, kVK_ANSI_1])
    func namedKeysAreAcceptedWithAModifier(keyCode: Int) {
        #expect(
            validate(keyCode, controlKey) == .accepted(Hotkey(keyCode: UInt32(keyCode), modifiers: UInt32(controlKey))))
    }

    @Test(arguments: [kVK_ANSI_K, kVK_Space, kVK_Return, kVK_Tab, kVK_LeftArrow])
    func otherKeysAloneAreRejected(keyCode: Int) {
        #expect(validate(keyCode) == .rejected(.missingModifier))
    }

    @Test(arguments: [kVK_ANSI_K, kVK_Space, kVK_ANSI_1])
    func shiftAloneIsRejected(keyCode: Int) {
        #expect(validate(keyCode, shiftKey, "k") == .rejected(.shiftOnly))
    }

    // MARK: - Esc and modifier keys

    @Test(arguments: [0, cmdKey, shiftKey, optionKey | controlKey])
    func escapeIsAlwaysReserved(modifiers: Int) {
        #expect(validate(kVK_Escape, modifiers) == .rejected(.escapeReserved))
    }

    @Test(arguments: [kVK_Shift, kVK_RightShift, kVK_Command, kVK_Option, kVK_Control, kVK_CapsLock, kVK_Function])
    func modifierKeysAloneAreRejected(keyCode: Int) {
        #expect(validate(keyCode, cmdKey) == .rejected(.modifierKeyOnly))
        #expect(validate(keyCode) == .rejected(.modifierKeyOnly))
    }

    // MARK: - Modifier masking

    @Test func unsupportedModifierBitsAreDropped() {
        let withCapsLock = cmdKey | alphaLock
        #expect(
            validate(kVK_ANSI_K, withCapsLock)
                == .accepted(Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey))))
        // Caps Lock does not count as a modifier.
        #expect(validate(kVK_ANSI_K, alphaLock) == .rejected(.missingModifier))
    }

    // MARK: - Stored hotkeys

    @Test func storedHotkeysFollowTheSameRules() {
        #expect(ShortcutValidator.rejection(for: .f6) == nil)
        #expect(ShortcutValidator.rejection(for: Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey))) == nil)
        #expect(ShortcutValidator.rejection(for: .escape) == .escapeReserved)
        #expect(ShortcutValidator.rejection(for: Hotkey(keyCode: UInt32(kVK_ANSI_K))) == .missingModifier)
        #expect(
            ShortcutValidator.rejection(for: Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(shiftKey)))
                == .shiftOnly)
    }

    @Test func storedHotkeysWithUnknownModifierBitsAreRejected() {
        let hotkey = Hotkey(keyCode: UInt32(kVK_F6), modifiers: UInt32(alphaLock))
        #expect(ShortcutValidator.rejection(for: hotkey) == .unsupportedModifiers)
    }

    // MARK: - AppKit to Carbon

    @Test func mapsEveryModifierFlag() {
        #expect(ShortcutValidator.carbonModifiers(from: []) == 0)
        #expect(ShortcutValidator.carbonModifiers(from: .command) == UInt32(cmdKey))
        #expect(ShortcutValidator.carbonModifiers(from: .option) == UInt32(optionKey))
        #expect(ShortcutValidator.carbonModifiers(from: .control) == UInt32(controlKey))
        #expect(ShortcutValidator.carbonModifiers(from: .shift) == UInt32(shiftKey))
        #expect(
            ShortcutValidator.carbonModifiers(from: [.command, .option, .control, .shift])
                == UInt32(cmdKey | optionKey | controlKey | shiftKey))
    }

    @Test func ignoresFlagsThatAreNotShortcutModifiers() {
        // Function keys and arrows arrive with `.function` and `.numericPad` set; Caps Lock may be on.
        let flags: NSEvent.ModifierFlags = [.command, .capsLock, .function, .numericPad, .help]
        #expect(ShortcutValidator.carbonModifiers(from: flags) == UInt32(cmdKey))
    }

    // MARK: - Labels

    @Test func labelsAreUppercasedForTheLocale() {
        #expect(ShortcutValidator.keyLabel(from: "k", locale: Self.english) == "K")
        #expect(ShortcutValidator.keyLabel(from: "ş", locale: Self.turkish) == "Ş")
        #expect(ShortcutValidator.keyLabel(from: "i", locale: Self.turkish) == "İ")
        #expect(ShortcutValidator.keyLabel(from: "ı", locale: Self.turkish) == "I")
        #expect(ShortcutValidator.keyLabel(from: "1", locale: Self.english) == "1")
    }

    @Test(arguments: [nil, "", " ", "\r", "\t", "\u{1B}", "\u{F704}", "\u{F739}"])
    func unprintableCharactersGiveNoLabel(characters: String?) {
        #expect(ShortcutValidator.keyLabel(from: characters, locale: Self.english) == nil)
    }

    @Test func turkishCharacterKeyIsRecordedWithItsLabel() {
        let outcome = ShortcutValidator.validate(
            RecordedKey(keyCode: UInt32(kVK_ANSI_Quote), modifiers: UInt32(controlKey | optionKey), characters: "i"),
            locale: Self.turkish)
        guard case .accepted(let hotkey) = outcome else {
            Issue.record("⌃⌥i must be accepted")
            return
        }
        #expect(hotkey.displayName == "⌃⌥İ")
    }
}
