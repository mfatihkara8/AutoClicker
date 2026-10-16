/// Why a click run ended. `ClickEngine` reports it exactly once per run through `onStop`.
enum StopReason: Sendable, Equatable {
    /// The user pressed Stop in the UI.
    case user
    /// The start/stop hotkey (F6) toggled the run off.
    case hotkey
    /// The scoped ESC emergency-stop hotkey was pressed.
    case emergencyEscape
    /// The cursor reached a screen corner (SPEC section 3.4).
    case cornerFailsafe
    /// The configured `StopCondition` was satisfied.
    case conditionMet
    /// Accessibility permission was revoked while the run was active.
    case permissionLost
}
