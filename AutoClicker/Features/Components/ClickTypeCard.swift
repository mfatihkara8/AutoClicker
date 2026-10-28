import SwiftUI

/// The click type posted on every tick, as a segmented picker over all types, and the modifiers held for each click.
struct ClickTypeCard: View {
    @Binding var clickType: ClickType
    @Binding var modifiers: ClickModifiers

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Click type", selection: $clickType) {
                    ForEach(ClickType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("clickTypePicker")

                ModifierToggleRow(modifiers: $modifiers, clickType: clickType)
            }
            .padding(4)
        } label: {
            Label("Click Type", systemImage: "cursorarrow.click.2")
                .font(.headline)
        }
    }
}

#Preview {
    @Previewable @State var clickType = ClickType.left
    @Previewable @State var modifiers: ClickModifiers = []
    ClickTypeCard(clickType: $clickType, modifiers: $modifiers)
        .padding()
        .frame(width: 480)
}
