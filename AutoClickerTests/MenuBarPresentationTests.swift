import Foundation
import Testing

@testable import AutoClicker

struct MenuBarPresentationTests {
    private static let locale = Locale(identifier: "en_US")

    private func presentation(
        isRunning: Bool,
        totalClicks: Int = 0,
        lastStopReason: StopReason? = nil,
        isHotkeyAvailable: Bool = true
    ) -> MenuBarPresentation {
        MenuBarPresentation(
            isRunning: isRunning,
            totalClicks: totalClicks,
            lastStopReason: lastStopReason,
            isHotkeyAvailable: isHotkeyAvailable,
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

    // MARK: - Start/Stop item

    @Test func startStopTitleShowsTheF6HintWhenTheHotkeyWorks() {
        #expect(presentation(isRunning: false).startStopTitle == "Start Clicking (F6)")
        #expect(presentation(isRunning: true).startStopTitle == "Stop Clicking (F6)")
    }

    @Test func startStopTitleOmitsTheF6HintWhenTheHotkeyIsUnavailable() {
        #expect(presentation(isRunning: false, isHotkeyAvailable: false).startStopTitle == "Start Clicking")
        #expect(presentation(isRunning: true, isHotkeyAvailable: false).startStopTitle == "Stop Clicking")
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
