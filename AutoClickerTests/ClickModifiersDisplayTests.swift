import Testing

@testable import AutoClicker

struct ClickModifiersDisplayTests {
    // MARK: - Glyphs and names

    @Test func noModifiersHaveNoSymbols() {
        #expect(ClickModifiers().symbols == "")
    }

    @Test func singleModifiersUseTheirMacOSGlyphs() {
        #expect(ClickModifiers.control.symbol == "⌃")
        #expect(ClickModifiers.option.symbol == "⌥")
        #expect(ClickModifiers.shift.symbol == "⇧")
        #expect(ClickModifiers.command.symbol == "⌘")
    }

    @Test func symbolsFollowMenuOrderWhateverTheInsertionOrder() {
        #expect(ClickModifiers([.command, .shift]).symbols == "⇧⌘")
        #expect(ClickModifiers([.command, .option]).symbols == "⌥⌘")
        #expect(ClickModifiers([.shift, .control]).symbols == "⌃⇧")
        #expect(ClickModifiers([.command, .shift, .option, .control]).symbols == "⌃⌥⇧⌘")
    }

    @Test func symbolsMatchTheHotkeyGlyphOrder() {
        // The same ⌃⌥⇧⌘ order the start/stop shortcut uses, so both read the same way.
        let hotkey = Hotkey(
            keyCode: VirtualKeyCode.f6,
            modifiers: Hotkey.Modifier.command | Hotkey.Modifier.shift | Hotkey.Modifier.option
                | Hotkey.Modifier.control)
        #expect(ClickModifiers([.shift, .control, .option, .command]).symbols == hotkey.modifierSymbols)
    }

    @Test func singleModifiersHaveTheirAccessibilityNames() {
        #expect(ClickModifiers.shift.displayName == "Shift")
        #expect(ClickModifiers.control.displayName == "Control")
        #expect(ClickModifiers.option.displayName == "Option")
        #expect(ClickModifiers.command.displayName == "Command")
    }

    // MARK: - ⌃-click hint

    @Test(arguments: [ClickType.left, .double])
    func controlWithAPrimaryButtonClickShowsTheHint(clickType: ClickType) {
        #expect(ClickModifiers.control.showsContextMenuHint(for: clickType))
        #expect(ClickModifiers([.control, .shift, .command]).showsContextMenuHint(for: clickType))
    }

    @Test(arguments: [ClickType.right, .middle])
    func controlWithOtherButtonsShowsNoHint(clickType: ClickType) {
        #expect(!ClickModifiers.control.showsContextMenuHint(for: clickType))
    }

    @Test(arguments: ClickType.allCases)
    func noHintWithoutControl(clickType: ClickType) {
        #expect(!ClickModifiers().showsContextMenuHint(for: clickType))
        #expect(!ClickModifiers([.shift, .option, .command]).showsContextMenuHint(for: clickType))
    }
}
