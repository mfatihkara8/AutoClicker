import Foundation

/// A global keyboard shortcut: a virtual key code plus a Carbon modifier mask.
///
/// The values are plain numbers so that this type stays free of Carbon; only `CarbonHotkeyManager`
/// talks to the system. `keyCode` is a `kVK_*` virtual key code and `modifiers` is a mask of Carbon
/// modifier flags (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`), with `0` meaning no modifiers.
struct Hotkey: Hashable, Sendable {
    /// The virtual key code (`kVK_*` from Carbon's `Events.h`).
    let keyCode: UInt32
    /// The Carbon modifier mask that must be held down, or `0` for none.
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32 = 0) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// F6 without modifiers: the default start/stop toggle (SPEC §3.3).
    ///
    /// The literal mirrors `kVK_F6`; `HotkeyTests` checks it against the Carbon constant.
    static let f6 = Hotkey(keyCode: 0x61)

    /// Escape without modifiers: the emergency stop, registered only while clicking (SPEC §3.4).
    ///
    /// The literal mirrors `kVK_Escape`; `HotkeyTests` checks it against the Carbon constant.
    static let escape = Hotkey(keyCode: 0x35)

    /// A short, human-readable name for hints in the UI, such as "F6" or "Esc".
    var displayName: String {
        switch self {
        case .f6:
            String(localized: "F6", comment: "Name of the F6 key in hotkey hints.")
        case .escape:
            String(localized: "Esc", comment: "Name of the Escape key in hotkey hints.")
        default:
            String(
                localized: "Key \(keyCode)",
                comment: "Fallback name for a hotkey without a known name; the argument is the key code."
            )
        }
    }
}
