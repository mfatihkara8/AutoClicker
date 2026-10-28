import Foundation
import Testing

@testable import AutoClicker

struct MenuBarPresentationTests {
    private static let locale = Locale(identifier: "en_US")

    private func presentation(
        isRunning: Bool,
        totalClicks: Int = 0,
        lastStopReason: StopReason? = nil,
        toggleHotkeyName: String? = "F6",
        clickType: ClickType = .left,
        modifiers: ClickModifiers = []
    ) -> MenuBarPresentation {
        MenuBarPresentation(
            isRunning: isRunning,
            totalClicks: totalClicks,
            lastStopReason: lastStopReason,
            toggleHotkeyName: toggleHotkeyName,
            clickType: clickType,
            modifiers: modifiers,
            locale: Self.locale
        )
    }

    // MARK: - Status line

    @Test func runningStatusShowsTheFormattedCount() {
        #expect(presentation(isRunning: true, totalClicks: 1234).statusText == "Clicking: 1,234 clicks")
    }

    @Test func runningStatusUsesTheSingularForOneClick() {
        #expect(presentation(isRunning: true, totalClicks: 1).statusText == "Clicking: 1 click")
    }

    @Test func runningStatusUsesThePluralForZeroClicks() {
        #expect(presentation(isRunning: true, totalClicks: 0).statusText == "Clicking: 0 clicks")
    }

    @Test func idleStatusBeforeAnyRunIsJustIdle() {
        #expect(presentation(isRunning: false, totalClicks: 42).statusText == "Idle")
    }

    @Test(arguments: [StopReason.user, .hotkey, .emergencyEscape, .cornerFailsafe, .conditionMet, .permissionLost])
    func idleStatusIncludesTheLastStopReason(reason: StopReason) {
        let text = presentation(isRunning: false, lastStopReason: reason).statusText
        #expect(text == "Idle — \(reason.displayText)")
    }

    @Test func runningStatusIgnoresAStaleStopReason() {
        let text = presentation(isRunning: true, totalClicks: 3, lastStopReason: .user).statusText
        #expect(text == "Clicking: 3 clicks")
    }

    // MARK: - Modifiers in the status line

    @Test func modifiedClickNameIsNilWithoutModifiers() {
        for type in ClickType.allCases {
            #expect(MenuBarPresentation.modifiedClickName(clickType: type, modifiers: []) == nil)
        }
    }

    @Test(arguments: [
        ModifiedClickCase(.left, .shift, "⇧-Left click"),
        ModifiedClickCase(.right, .control, "⌃-Right click"),
        ModifiedClickCase(.middle, .option, "⌥-Middle click"),
        ModifiedClickCase(.double, .command, "⌘-Double click"),
        ModifiedClickCase(.double, [.command, .shift], "⇧⌘-Double click"),
        ModifiedClickCase(.left, [.command, .shift, .option, .control], "⌃⌥⇧⌘-Left click"),
    ])
    func modifiedClickNameListsTheGlyphsInMenuOrder(testCase: ModifiedClickCase) {
        #expect(
            MenuBarPresentation.modifiedClickName(clickType: testCase.clickType, modifiers: testCase.modifiers)
                == testCase.expected)
    }

    @Test func runningStatusNamesTheModifiedClick() {
        let text = presentation(isRunning: true, totalClicks: 1234, modifiers: .shift).statusText
        #expect(text == "Clicking: 1,234 clicks (⇧-Left click)")
    }

    @Test func runningStatusNamesTheModifiedClickForOneClick() {
        let text = presentation(isRunning: true, totalClicks: 1, clickType: .double, modifiers: [.shift, .command])
            .statusText
        #expect(text == "Clicking: 1 click (⇧⌘-Double click)")
    }

    @Test(arguments: ClickType.allCases)
    func runningStatusWithoutModifiersOmitsTheClick(clickType: ClickType) {
        #expect(presentation(isRunning: true, totalClicks: 5, clickType: clickType).statusText == "Clicking: 5 clicks")
    }

    @Test func idleStatusIgnoresTheModifiers() {
        #expect(presentation(isRunning: false, modifiers: .command).statusText == "Idle")
        #expect(
            presentation(isRunning: false, lastStopReason: .user, modifiers: .command).statusText
                == "Idle — \(StopReason.user.displayText)")
    }

    // MARK: - Start/Stop item

    @Test func startStopTitleShowsTheF6HintWhenTheHotkeyWorks() {
        #expect(presentation(isRunning: false).startStopTitle == "Start Clicking (F6)")
        #expect(presentation(isRunning: true).startStopTitle == "Stop Clicking (F6)")
    }

    @Test func startStopTitleShowsACustomShortcut() {
        let shortcut = Hotkey(keyCode: 0x28, modifiers: Hotkey.Modifier.control | Hotkey.Modifier.option, keyLabel: "K")
        #expect(
            presentation(isRunning: false, toggleHotkeyName: shortcut.displayName).startStopTitle
                == "Start Clicking (⌃⌥K)")
        #expect(
            presentation(isRunning: true, toggleHotkeyName: shortcut.displayName).startStopTitle
                == "Stop Clicking (⌃⌥K)")
    }

    @Test func startStopTitleOmitsTheHintWhenTheShortcutIsUnavailable() {
        #expect(presentation(isRunning: false, toggleHotkeyName: nil).startStopTitle == "Start Clicking")
        #expect(presentation(isRunning: true, toggleHotkeyName: nil).startStopTitle == "Stop Clicking")
    }

    // MARK: - Icon

    @Test func iconDiffersBetweenIdleAndRunning() {
        #expect(MenuBarPresentation.symbolName(isRunning: false) == "cursorarrow.click")
        #expect(MenuBarPresentation.symbolName(isRunning: true) == "cursorarrow.click.2")
    }

    @Test func iconAccessibilityLabelNamesTheState() {
        #expect(MenuBarPresentation.accessibilityLabel(isRunning: false) == "AutoClicker, idle")
        #expect(MenuBarPresentation.accessibilityLabel(isRunning: true) == "AutoClicker, clicking")
    }
}

/// One `modifiedClickName` case; a named type because `@Test` cannot infer tuple arguments with option set literals.
struct ModifiedClickCase: Sendable, CustomTestStringConvertible {
    let clickType: ClickType
    let modifiers: ClickModifiers
    let expected: String

    init(_ clickType: ClickType, _ modifiers: ClickModifiers, _ expected: String) {
        self.clickType = clickType
        self.modifiers = modifiers
        self.expected = expected
    }

    var testDescription: String { expected }
}
