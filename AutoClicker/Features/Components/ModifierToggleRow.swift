import SwiftUI

/// The "Hold" form row: one button-style toggle per modifier (⌃ ⌥ ⇧ ⌘) held for every click, with the ⌃-click hint
/// as the row's subtitle when it applies.
///
/// Locked while clicking through the parent's `.disabled`, like every other setting.
struct ModifierToggleRow: View {
    @Binding var modifiers: ClickModifiers
    /// The selected click type, needed only to decide whether the ⌃-click hint applies.
    let clickType: ClickType

    var body: some View {
        LabeledContent {
            ControlGroup {
                ForEach(ClickModifiers.menuOrder, id: \.rawValue) { modifier in
                    Toggle(isOn: binding(for: modifier)) {
                        Text(verbatim: modifier.symbol)
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel(Text(modifier.displayName))
                    // The raw bit, not the localized name, so UI tests stay stable in every language.
                    .accessibilityIdentifier("modifierToggle.\(modifier.rawValue)")
                }
            }
            .fixedSize()
        } label: {
            Text("Hold")
            // A subtitle rather than its own row, so the hint does not push the Click tab into scrolling.
            if modifiers.showsContextMenuHint(for: clickType) {
                Text("⌃-click opens context menus.")
            }
        }
    }

    private func binding(for modifier: ClickModifiers) -> Binding<Bool> {
        Binding(
            get: { modifiers.contains(modifier) },
            set: { isOn in
                if isOn {
                    modifiers.insert(modifier)
                } else {
                    modifiers.remove(modifier)
                }
            })
    }
}

#Preview {
    @Previewable @State var modifiers: ClickModifiers = [.control]
    Form {
        ModifierToggleRow(modifiers: $modifiers, clickType: .left)
    }
    .formStyle(.grouped)
    .frame(width: 480)
}
