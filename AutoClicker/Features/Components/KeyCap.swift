import SwiftUI

/// A key or shortcut drawn as a small key cap, such as "F6" or "⌃⌥K", shared by the hint and the shortcut card.
struct KeyCap: View {
    let text: Text

    /// Creates a key cap from a localized key, such as "Esc".
    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    /// Creates a key cap from a name that is already localized, such as `Hotkey.displayName`.
    init(verbatim name: String) {
        text = Text(verbatim: name)
    }

    var body: some View {
        text
            .font(.callout.monospaced().weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    HStack {
        KeyCap(verbatim: "F6")
        KeyCap(verbatim: "⌃⌥⇧⌘K")
        KeyCap("Esc")
    }
    .padding()
}
