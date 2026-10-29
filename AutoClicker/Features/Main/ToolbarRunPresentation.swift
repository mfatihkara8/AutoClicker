import Foundation

/// The text and symbols of the toolbar's status indicator and round Start/Stop button for a given run state
/// (SPEC §3.5).
///
/// Kept as a plain value so the wording can be unit tested without building any SwiftUI view or toolbar.
struct ToolbarRunPresentation: Equatable {
    let isRunning: Bool
    let canStart: Bool
    /// The display name of the start/stop shortcut, such as "F6" or "⌃⌥K", or `nil` when it is not registered and the
    /// tooltip must not advertise it.
    let toggleHotkeyName: String?

    /// The status indicator's text. It never shows the click count, so it stays a fixed width while clicking.
    var statusText: String {
        isRunning
            ? String(localized: "Active", comment: "Toolbar status indicator while clicking.")
            : String(localized: "Idle", comment: "Toolbar status indicator while not clicking.")
    }

    /// The SF Symbol of the icon-only Start/Stop button.
    var buttonSymbolName: String {
        isRunning ? "stop.fill" : "play.fill"
    }

    /// The button's VoiceOver label, which stands in for the title the icon-only button does not show.
    var buttonAccessibilityLabel: String {
        isRunning
            ? String(localized: "Stop", comment: "Accessibility label of the toolbar button that stops clicking.")
            : String(localized: "Start", comment: "Accessibility label of the toolbar button that starts clicking.")
    }

    /// Whether the button is disabled: only starting needs Accessibility permission, stopping always works.
    var isButtonDisabled: Bool {
        !isRunning && !canStart
    }

    /// The button's tooltip, which names the shortcut that does the same thing, as in "Start (F6)".
    var buttonHelp: String {
        switch (isRunning, toggleHotkeyName) {
        case (true, let shortcut?):
            String(
                localized: "Stop (\(shortcut))",
                comment: "Tooltip of the toolbar Stop button; the argument is the start/stop shortcut, such as F6.")
        case (true, nil):
            // Esc always stops a run, even when the start/stop shortcut is not registered.
            String(
                localized: "Stop (Esc)", comment: "Tooltip of the toolbar Stop button without a start/stop shortcut.")
        case (false, _) where !canStart:
            String(
                localized: "Grant Accessibility permission to start",
                comment: "Tooltip of the disabled toolbar Start button while Accessibility permission is missing.")
        case (false, let shortcut?):
            String(
                localized: "Start (\(shortcut))",
                comment: "Tooltip of the toolbar Start button; the argument is the start/stop shortcut, such as F6.")
        case (false, nil):
            String(localized: "Start", comment: "Tooltip of the toolbar Start button without a start/stop shortcut.")
        }
    }
}
