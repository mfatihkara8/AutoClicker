import SwiftUI

/// The "Hold" row: one button-style toggle per modifier (⌃ ⌥ ⇧ ⌘) held for every click, plus the ⌃-click hint.
///
/// Locked while clicking through the parent's `.disabled`, like every other setting.
struct ModifierToggleRow: View {
    @Binding var modifiers: ClickModifiers
    /// The selected click type, needed only to decide whether the ⌃-click hint applies.
    let clickType: ClickType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Hold")
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
                Spacer(minLength: 0)
            }

            if modifiers.showsContextMenuHint(for: clickType) {
                Text("⌃-click opens the context menu in most apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    ModifierToggleRow(modifiers: $modifiers, clickType: .left)
        .padding()
        .frame(width: 480)
}
