import Foundation

// The user-facing wording lives in `Features/` so that `Core/` stays free of UI concerns.
extension ShortcutValidator.Rejection {
    /// A short, localized hint that tells the user why the key cannot be the start/stop shortcut and what works.
    var displayText: String {
        switch self {
        case .escapeReserved:
            String(
                localized: "Esc is reserved for the emergency stop.",
                comment: "Shortcut recorder hint: Esc cannot be the start/stop shortcut.")
        case .modifierKeyOnly:
            String(
                localized: "Press a key together with ⌘, ⌥ or ⌃.",
                comment: "Shortcut recorder hint: only a modifier key such as Shift was pressed.")
        case .shiftOnly:
            String(
                localized: "Shift alone is not enough. Add ⌘, ⌥ or ⌃, or use F1–F20.",
                comment: "Shortcut recorder hint: a key was pressed with Shift as its only modifier.")
        case .missingModifier:
            String(
                localized: "Use F1–F20 alone, or another key with ⌘, ⌥ or ⌃.",
                comment: "Shortcut recorder hint: a key other than F1–F20 was pressed without a modifier.")
        case .unsupportedModifiers:
            String(
                localized: "Use only ⌘, ⌥, ⌃ and ⇧ as modifiers.",
                comment: "Shortcut recorder hint: the shortcut contains an unsupported modifier.")
        }
    }
}
