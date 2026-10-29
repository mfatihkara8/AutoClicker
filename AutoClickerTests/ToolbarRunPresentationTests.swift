import Testing

@testable import AutoClicker

struct ToolbarRunPresentationTests {
    @Test func idleShowsIdleAndPlay() {
        let presentation = ToolbarRunPresentation(isRunning: false, canStart: true, toggleHotkeyName: "F6")
        #expect(presentation.statusText == "Idle")
        #expect(presentation.buttonSymbolName == "play.fill")
        #expect(presentation.buttonAccessibilityLabel == "Start")
        #expect(presentation.buttonHelp == "Start (F6)")
        #expect(!presentation.isButtonDisabled)
    }

    @Test func runningShowsActiveAndStop() {
        let presentation = ToolbarRunPresentation(isRunning: true, canStart: true, toggleHotkeyName: "F6")
        #expect(presentation.statusText == "Active")
        #expect(presentation.buttonSymbolName == "stop.fill")
        #expect(presentation.buttonAccessibilityLabel == "Stop")
        #expect(presentation.buttonHelp == "Stop (F6)")
        #expect(!presentation.isButtonDisabled)
    }

    @Test func helpNamesACustomShortcut() {
        let presentation = ToolbarRunPresentation(isRunning: false, canStart: true, toggleHotkeyName: "⌃⌥K")
        #expect(presentation.buttonHelp == "Start (⌃⌥K)")
    }

    @Test func helpWithoutAShortcutDoesNotAdvertiseOne() {
        let idle = ToolbarRunPresentation(isRunning: false, canStart: true, toggleHotkeyName: nil)
        let running = ToolbarRunPresentation(isRunning: true, canStart: true, toggleHotkeyName: nil)
        #expect(idle.buttonHelp == "Start")
        // Esc stops every run, so the tooltip still names it.
        #expect(running.buttonHelp == "Stop (Esc)")
    }

    @Test func startIsDisabledWithoutPermission() {
        let presentation = ToolbarRunPresentation(isRunning: false, canStart: false, toggleHotkeyName: "F6")
        #expect(presentation.isButtonDisabled)
        #expect(presentation.buttonHelp == "Grant Accessibility permission to start")
    }

    @Test func stopStaysEnabledWithoutPermission() {
        let presentation = ToolbarRunPresentation(isRunning: true, canStart: false, toggleHotkeyName: "F6")
        #expect(!presentation.isButtonDisabled)
        #expect(presentation.buttonHelp == "Stop (F6)")
    }
}
