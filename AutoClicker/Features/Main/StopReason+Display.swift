import Foundation

// The user-facing wording lives in `Features/` so that `Core/` stays free of UI concerns.
extension StopReason {
    /// A short, localized sentence explaining why the last run ended, for the status area.
    var displayText: String {
        switch self {
        case .user:
            String(localized: "Stopped by you.", comment: "Stop reason: the user pressed Stop.")
        case .hotkey:
            String(localized: "Stopped with F6.", comment: "Stop reason: the F6 start/stop hotkey was pressed.")
        case .emergencyEscape:
            String(localized: "Stopped with Esc.", comment: "Stop reason: the Esc emergency stop was pressed.")
        case .cornerFailsafe:
            String(
                localized: "Stopped because the cursor reached a screen corner.",
                comment: "Stop reason: the corner failsafe fired.")
        case .conditionMet:
            String(
                localized: "Stopped because the stop condition was reached.",
                comment: "Stop reason: the configured click count or duration was reached.")
        case .permissionLost:
            String(
                localized: "Stopped because Accessibility permission was revoked.",
                comment: "Stop reason: Accessibility permission was lost while clicking.")
        }
    }
}
