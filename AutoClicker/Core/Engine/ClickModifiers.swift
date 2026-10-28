/// The modifier keys held for every click of a run: any combination of Shift, Control, Option and Command
/// (SPEC §3.2, ADR-009). The empty set means a plain click.
///
/// ## Persistence
/// Encoded as an array of stable names in menu order, such as `["shift","command"]` for ⇧⌘, rather than as the raw
/// bit mask, so the stored settings stay readable and do not depend on the bit layout. Unknown names are ignored on
/// decode, so settings written by a later build that knows more modifiers still load.
struct ClickModifiers: OptionSet, Sendable, Hashable, Codable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// ⇧ Shift.
    static let shift = ClickModifiers(rawValue: 1 << 0)
    /// ⌃ Control.
    static let control = ClickModifiers(rawValue: 1 << 1)
    /// ⌥ Option.
    static let option = ClickModifiers(rawValue: 1 << 2)
    /// ⌘ Command.
    static let command = ClickModifiers(rawValue: 1 << 3)

    /// Every single modifier, in the order macOS menus list them: ⌃ Control, ⌥ Option, ⇧ Shift, ⌘ Command.
    static let menuOrder: [ClickModifiers] = [.control, .option, .shift, .command]

    /// The single modifiers in this set, in `menuOrder`.
    var elementsInMenuOrder: [ClickModifiers] {
        Self.menuOrder.filter { contains($0) }
    }

    init(from decoder: any Decoder) throws {
        let names = try decoder.singleValueContainer().decode([String].self)
        self = []
        for name in names {
            if let modifier = Self.storageNames.first(where: { $0.name == name })?.modifier {
                insert(modifier)
            }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let names = Self.storageNames.filter { contains($0.modifier) }.map(\.name)
        try container.encode(names)
    }

    /// The persisted name of each single modifier, in menu order. These strings are stored by `SettingsStore`, so they
    /// must never change.
    private static let storageNames: [(modifier: ClickModifiers, name: String)] = [
        (.control, "control"),
        (.option, "option"),
        (.shift, "shift"),
        (.command, "command"),
    ]
}
