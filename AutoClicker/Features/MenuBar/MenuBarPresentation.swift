import Foundation

/// The text and symbols the menu bar extra shows for a given run state.
///
/// Kept as a plain value so the wording can be unit tested without building any SwiftUI view or menu.
struct MenuBarPresentation: Equatable {
    /// The SF Symbol shown in the menu bar while idle.
    static let idleSymbolName = "cursorarrow.click"
    /// The SF Symbol shown while clicking; the double click makes the active state visible at a glance.
    static let runningSymbolName = "cursorarrow.click.2"

    let isRunning: Bool
    let totalClicks: Int
    let lastStopReason: StopReason?
    /// The display name of the start/stop shortcut, such as "F6" or "⌃⌥K", or `nil` when it is not registered and the
    /// menu must not advertise it.
    let toggleHotkeyName: String?
    /// The click type of the run; named in the status only together with modifiers.
    let clickType: ClickType
    /// The modifiers held for every click of the run.
    let modifiers: ClickModifiers
    /// The locale used to format the click count; injected so tests do not depend on the machine's settings.
    var locale: Locale = .current

    /// The first, non-interactive line of the menu.
    ///
    /// While running with modifiers held it also names the modified click, as in "Clicking: 12 clicks (⇧-Left click)",
    /// so a run that Shift- or Command-clicks is never mistaken for a plain one. Plain runs keep the short text.
    var statusText: String {
        if isRunning {
            let count = totalClicks.formatted(.number.locale(locale))
            let status =
                if totalClicks == 1 {
                    String(
                        localized: "Clicking: \(count) click",
                        comment:
                            "Menu bar status while running, for exactly one click; the argument is the formatted count."
                    )
                } else {
                    String(
                        localized: "Clicking: \(count) clicks",
                        comment: "Menu bar status while running; the argument is the formatted total click count.")
                }
            guard let modifiedClick = Self.modifiedClickName(clickType: clickType, modifiers: modifiers) else {
                return status
            }
            return String(
                localized: "\(status) (\(modifiedClick))",
                comment: "Menu bar status with modifiers held; the arguments are the count status and the click.")
        }
        guard let lastStopReason else {
            return String(localized: "Idle", comment: "Menu bar status while not clicking and before any run ended.")
        }
        return String(
            localized: "Idle — \(lastStopReason.displayText)",
            comment: "Menu bar status while not clicking; the argument explains why the last run ended.")
    }

    /// The title of the Start/Stop item, with the current shortcut as a hint when it works.
    ///
    /// The hint is part of the title rather than a key equivalent: a menu key equivalent for the shortcut could fire
    /// alongside the global Carbon hotkey while the menu is open and toggle the run twice.
    var startStopTitle: String {
        switch (isRunning, toggleHotkeyName) {
        case (true, let shortcut?):
            String(
                localized: "Stop Clicking (\(shortcut))",
                comment: "Menu bar item that stops clicking; the argument is the start/stop shortcut, such as F6.")
        case (true, nil):
            String(
                localized: "Stop Clicking",
                comment: "Menu bar item that stops clicking, when the start/stop shortcut is unavailable.")
        case (false, let shortcut?):
            String(
                localized: "Start Clicking (\(shortcut))",
                comment: "Menu bar item that starts clicking; the argument is the start/stop shortcut, such as F6.")
        case (false, nil):
            String(
                localized: "Start Clicking",
                comment: "Menu bar item that starts clicking, when the start/stop shortcut is unavailable.")
        }
    }

    /// The click named with its modifier glyphs in menu order, such as "⇧-Left click" or "⇧⌘-Double click", or `nil`
    /// for a plain click without modifiers.
    static func modifiedClickName(clickType: ClickType, modifiers: ClickModifiers) -> String? {
        guard !modifiers.isEmpty else { return nil }
        return String(
            localized: "\(modifiers.symbols)-\(clickType.clickName)",
            comment:
                "A click with modifier keys held; the arguments are the modifier glyphs and the click, such as Left click."
        )
    }

    /// The SF Symbol for the menu bar icon.
    ///
    /// Static, and keyed on the run state alone, so the icon's view observes `isRunning` but not the click count,
    /// which changes 15 times a second while running.
    static func symbolName(isRunning: Bool) -> String {
        isRunning ? runningSymbolName : idleSymbolName
    }

    /// What VoiceOver reads for the menu bar icon, which has no visible text.
    static func accessibilityLabel(isRunning: Bool) -> String {
        if isRunning {
            return String(
                localized: "AutoClicker, clicking", comment: "Accessibility label of the menu bar icon while running.")
        }
        return String(localized: "AutoClicker, idle", comment: "Accessibility label of the menu bar icon while idle.")
    }
}
