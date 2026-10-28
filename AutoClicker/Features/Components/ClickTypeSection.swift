import SwiftUI

/// The Click tab's "Click" section: the click type posted on every tick and the modifiers held for each click.
struct ClickTypeSection: View {
    @Binding var clickType: ClickType
    @Binding var modifiers: ClickModifiers

    var body: some View {
        Section("Click") {
            Picker("Type", selection: $clickType) {
                ForEach(ClickType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("clickTypePicker")

            ModifierToggleRow(modifiers: $modifiers, clickType: clickType)
        }
    }
}

#Preview {
    @Previewable @State var clickType = ClickType.left
    @Previewable @State var modifiers: ClickModifiers = [.control]
    Form {
        ClickTypeSection(clickType: $clickType, modifiers: $modifiers)
    }
    .formStyle(.grouped)
    .frame(width: 480)
}
