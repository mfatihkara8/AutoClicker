import Foundation

/// A global keyboard shortcut: a virtual key code plus a Carbon modifier mask, and optionally the label of its key.
///
/// The values are plain numbers so that this type stays free of Carbon; only `CarbonHotkeyManager`
/// talks to the system. `keyCode` is a `kVK_*` virtual key code and `modifiers` is a mask of Carbon
/// modifier flags (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`), with `0` meaning no modifiers.
///
/// ## Identity
/// Equality and hashing use `keyCode` and `modifiers` only. They are what the system registers, so two hotkeys that
/// differ only in `keyLabel` are the same shortcut: registering one and unregistering the other must match, and
/// `HotkeyProviding` implementations key their registrations by this identity.
///
/// ## Persistence
/// `Hotkey` is `Codable` with explicit keys (`keyCode`, `modifiers`, `keyLabel`), so renaming a property cannot
/// silently change the stored settings (ADR-007, ADR-008).
struct Hotkey: Hashable, Sendable, Codable {
    /// The virtual key code (`kVK_*` from Carbon's `Events.h`).
    let keyCode: UInt32
    /// The Carbon modifier mask that must be held down, or `0` for none.
    let modifiers: UInt32
    /// What the key shows on the user's keyboard layout, such as "K" or "Ş", captured when the shortcut was recorded.
    ///
    /// Virtual key codes name physical positions on an ANSI keyboard, so only the layout active at recording time
    /// knows what a character key is called. Keys with a fixed name (function keys, Esc, Space, arrows…) ignore it.
    let keyLabel: String?

    init(keyCode: UInt32, modifiers: UInt32 = 0, keyLabel: String? = nil) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// F6 without modifiers: the default start/stop toggle (SPEC §3.3).
    static let f6 = Hotkey(keyCode: VirtualKeyCode.f6)

    /// Escape without modifiers: the emergency stop, registered only while clicking (SPEC §3.4).
    static let escape = Hotkey(keyCode: VirtualKeyCode.escape)

    /// A short, human-readable name for the UI: the modifier glyphs in macOS order (⌃⌥⇧⌘), then the key's name.
    ///
    /// Examples: "F6", "Esc", "⌃⌥K", "⇧⌘Space".
    var displayName: String {
        modifierSymbols + keyName
    }

    /// The modifier glyphs in the order macOS menus use: Control, Option, Shift, Command.
    var modifierSymbols: String {
        var symbols = ""
        if modifiers & Modifier.control != 0 { symbols += "⌃" }
        if modifiers & Modifier.option != 0 { symbols += "⌥" }
        if modifiers & Modifier.shift != 0 { symbols += "⇧" }
        if modifiers & Modifier.command != 0 { symbols += "⌘" }
        return symbols
    }

    /// The name of the key without modifiers: a fixed name when the key has one, else the recorded label.
    var keyName: String {
        if let name = VirtualKeyCode.fixedName(for: keyCode) {
            return name
        }
        if let keyLabel, !keyLabel.isEmpty {
            return keyLabel
        }
        return String(
            localized: "Key \(keyCode)",
            comment: "Fallback name for a hotkey without a known name; the argument is the key code.")
    }

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
        case keyLabel
    }

    /// The Carbon modifier bits, mirrored as literals so this type needs no Carbon import.
    ///
    /// `HotkeyTests` checks each literal against the Carbon constant it mirrors.
    enum Modifier {
        /// Mirrors Carbon's `cmdKey`.
        static let command: UInt32 = 1 << 8
        /// Mirrors Carbon's `shiftKey`.
        static let shift: UInt32 = 1 << 9
        /// Mirrors Carbon's `optionKey`.
        static let option: UInt32 = 1 << 11
        /// Mirrors Carbon's `controlKey`.
        static let control: UInt32 = 1 << 12
    }
}
