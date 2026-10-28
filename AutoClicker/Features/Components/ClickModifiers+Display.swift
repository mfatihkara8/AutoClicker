import Foundation

// The glyphs and names live in `Features/` so that `Core/` stays free of UI concerns; `Core` only owns the order.
extension ClickModifiers {
    /// The glyphs of the held modifiers in macOS menu order (⌃⌥⇧⌘), such as "⇧⌘", or "" for none.
    var symbols: String {
        elementsInMenuOrder.map(\.symbol).joined()
    }

    /// The glyph of a single modifier, such as "⇧". A set of several modifiers uses `symbols` instead.
    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        default: symbols
        }
    }

    /// The localized name of a single modifier, such as "Shift", read by VoiceOver for its toggle.
    var displayName: String {
        switch self {
        case .control: String(localized: "Control", comment: "Modifier key held for every click.")
        case .option: String(localized: "Option", comment: "Modifier key held for every click.")
        case .shift: String(localized: "Shift", comment: "Modifier key held for every click.")
        case .command: String(localized: "Command", comment: "Modifier key held for every click.")
        default: elementsInMenuOrder.map(\.displayName).formatted(.list(type: .and))
        }
    }

    /// Whether to warn that the run will open context menus: in most apps a ⌃-click with the primary button is a
    /// secondary click, which is rarely what someone repeating a left or double click wants.
    func showsContextMenuHint(for clickType: ClickType) -> Bool {
        guard contains(.control) else { return false }
        switch clickType {
        case .left, .double: return true
        case .right, .middle: return false
        }
    }
}
