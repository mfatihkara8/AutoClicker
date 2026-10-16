import AppKit
import Carbon

/// Decides whether a recorded key press may become the start/stop shortcut (SPEC §3.3, ADR-008).
///
/// The rules, checked in this order:
/// 1. Esc is reserved for the emergency stop, whatever the modifiers. Recording treats it as "cancel".
/// 2. A modifier key on its own (Shift, ⌘, Caps Lock…) is not a shortcut.
/// 3. F1–F20 are accepted alone or with any modifiers.
/// 4. Any other key needs at least one of ⌘, ⌥ or ⌃. Shift alone is not enough, because ⇧A would steal a capital A
///    from every app.
///
/// Everything here is pure, so it is tested without AppKit events or Carbon registrations.
enum ShortcutValidator {
    /// Why a key press cannot be the start/stop shortcut.
    enum Rejection: Equatable, Sendable {
        /// Esc is the fixed emergency stop. While recording it means "cancel".
        case escapeReserved
        /// Only a modifier key was pressed.
        case modifierKeyOnly
        /// A non-function key was pressed with Shift as its only modifier.
        case shiftOnly
        /// A non-function key was pressed without any modifier.
        case missingModifier
        /// The modifier mask has bits other than ⌘, ⌥, ⌃ and ⇧. Recording never produces this; stored data might.
        case unsupportedModifiers
    }

    /// The result of validating a recorded key.
    enum Outcome: Equatable, Sendable {
        /// The key is a valid shortcut. Its `keyLabel` is set for character keys only.
        case accepted(Hotkey)
        case rejected(Rejection)
    }

    /// ⌘, ⌥ and ⌃: one of them makes a non-function key acceptable.
    static let requiredModifiers = UInt32(cmdKey | optionKey | controlKey)

    /// The Carbon modifiers a shortcut may contain. Other bits, such as Caps Lock, are dropped.
    static let supportedModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    /// Validates `key` and, when it is acceptable, builds the `Hotkey` to register.
    ///
    /// - Parameter locale: Used to uppercase the key label, so a Turkish "i" becomes "İ".
    static func validate(_ key: RecordedKey, locale: Locale = .current) -> Outcome {
        let modifiers = key.modifiers & supportedModifiers
        if let rejection = rejection(keyCode: key.keyCode, modifiers: modifiers) {
            return .rejected(rejection)
        }
        let label =
            VirtualKeyCode.fixedName(for: key.keyCode) == nil ? keyLabel(from: key.characters, locale: locale) : nil
        return .accepted(Hotkey(keyCode: key.keyCode, modifiers: modifiers, keyLabel: label))
    }

    /// Returns why `hotkey` cannot be the start/stop shortcut, or `nil` when it can.
    ///
    /// `SettingsStore` uses this to refuse a stored shortcut that a valid recording could never have produced.
    static func rejection(for hotkey: Hotkey) -> Rejection? {
        if hotkey.modifiers & ~supportedModifiers != 0 {
            return .unsupportedModifiers
        }
        return rejection(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
    }

    /// Converts AppKit modifier flags to the Carbon mask `RegisterEventHotKey` expects.
    ///
    /// Only ⌘, ⌥, ⌃ and ⇧ are mapped; Caps Lock, Fn and the numeric-pad flag are not part of a shortcut.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    /// The label to store for a character key: `characters` uppercased, or `nil` when it is not printable.
    ///
    /// AppKit reports keys without a character (such as Clear) as control characters or private-use code points
    /// (U+F700…); those would render as boxes, so the key falls back to its fixed name or key code instead.
    static func keyLabel(from characters: String?, locale: Locale = .current) -> String? {
        guard let characters else { return nil }
        let trimmed = characters.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let isPrintable = trimmed.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xE000...0xF8FF).contains(scalar.value)
        }
        guard isPrintable else { return nil }
        return trimmed.uppercased(with: locale)
    }

    private static func rejection(keyCode: UInt32, modifiers: UInt32) -> Rejection? {
        if keyCode == VirtualKeyCode.escape {
            return .escapeReserved
        }
        if VirtualKeyCode.isModifierKey(keyCode) {
            return .modifierKeyOnly
        }
        if VirtualKeyCode.isFunctionKey(keyCode) || modifiers & requiredModifiers != 0 {
            return nil
        }
        return modifiers & UInt32(shiftKey) != 0 ? .shiftOnly : .missingModifier
    }
}
