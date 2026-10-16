import Foundation

/// The virtual key codes the hotkey code needs by name, and the fixed display names of non-character keys.
///
/// The literals mirror the `kVK_*` constants from Carbon's `Events.h`, so `Hotkey` can use them without importing
/// Carbon. `VirtualKeyCodeTests` checks every literal against its Carbon constant.
enum VirtualKeyCode {
    static let escape: UInt32 = 0x35
    static let space: UInt32 = 0x31
    static let `return`: UInt32 = 0x24
    static let keypadEnter: UInt32 = 0x4C
    static let tab: UInt32 = 0x30
    static let delete: UInt32 = 0x33
    static let forwardDelete: UInt32 = 0x75
    static let leftArrow: UInt32 = 0x7B
    static let rightArrow: UInt32 = 0x7C
    static let downArrow: UInt32 = 0x7D
    static let upArrow: UInt32 = 0x7E
    static let home: UInt32 = 0x73
    static let end: UInt32 = 0x77
    static let pageUp: UInt32 = 0x74
    static let pageDown: UInt32 = 0x79
    static let help: UInt32 = 0x72
    static let f6: UInt32 = 0x61

    /// F1 to F20, in order, so `functionKeys[n - 1]` is the key code of Fn.
    static let functionKeys: [UInt32] = [
        0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D,
        0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A,
    ]

    /// The keys that only modify others: Command, Shift, Caps Lock, Option, Control (left and right) and Fn.
    static let modifierKeys: Set<UInt32> = [0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F]

    /// The function-key number (1–20) of `keyCode`, or `nil` when it is not F1–F20.
    static func functionKeyNumber(of keyCode: UInt32) -> Int? {
        functionKeys.firstIndex(of: keyCode).map { $0 + 1 }
    }

    /// Whether `keyCode` is one of F1–F20.
    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        functionKeyNumber(of: keyCode) != nil
    }

    /// Whether `keyCode` is a modifier key on its own, such as Shift or Command.
    static func isModifierKey(_ keyCode: UInt32) -> Bool {
        modifierKeys.contains(keyCode)
    }

    /// The layout-independent name of a non-character key, or `nil` for a character key.
    ///
    /// Character keys have no fixed name: what they show depends on the keyboard layout, so `Hotkey` uses the label
    /// captured at recording time instead.
    static func fixedName(for keyCode: UInt32) -> String? {
        if let number = functionKeyNumber(of: keyCode) {
            return String(
                localized: "F\(number)", comment: "Name of a function key in shortcuts; the argument is its number.")
        }
        switch keyCode {
        case escape:
            return String(localized: "Esc", comment: "Name of the Escape key in shortcuts.")
        case space:
            return String(localized: "Space", comment: "Name of the Space bar in shortcuts.")
        case `return`:
            return String(localized: "Return", comment: "Name of the Return key in shortcuts.")
        case keypadEnter:
            return String(localized: "Enter", comment: "Name of the keypad Enter key in shortcuts.")
        case tab:
            return String(localized: "Tab", comment: "Name of the Tab key in shortcuts.")
        case delete:
            return String(localized: "Delete", comment: "Name of the Delete (backspace) key in shortcuts.")
        case forwardDelete:
            return String(localized: "Forward Delete", comment: "Name of the Forward Delete key in shortcuts.")
        case home:
            return String(localized: "Home", comment: "Name of the Home key in shortcuts.")
        case end:
            return String(localized: "End", comment: "Name of the End key in shortcuts.")
        case pageUp:
            return String(localized: "Page Up", comment: "Name of the Page Up key in shortcuts.")
        case pageDown:
            return String(localized: "Page Down", comment: "Name of the Page Down key in shortcuts.")
        case help:
            return String(localized: "Help", comment: "Name of the Help key in shortcuts.")
        // Arrows use the glyphs macOS menus show; they read the same in every language.
        case leftArrow:
            return "←"
        case rightArrow:
            return "→"
        case downArrow:
            return "↓"
        case upArrow:
            return "↑"
        default:
            return nil
        }
    }
}
