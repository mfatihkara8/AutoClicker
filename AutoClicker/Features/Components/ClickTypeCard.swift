import SwiftUI

/// The click type posted on every tick, as a segmented picker over all types.
struct ClickTypeCard: View {
    @Binding var clickType: ClickType

    var body: some View {
        GroupBox {
            Picker("Click type", selection: $clickType) {
                ForEach(ClickType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(4)
            .accessibilityIdentifier("clickTypePicker")
        } label: {
            Label("Click Type", systemImage: "cursorarrow.click.2")
                .font(.headline)
        }
    }
}

#Preview {
    @Previewable @State var clickType = ClickType.left
    ClickTypeCard(clickType: $clickType)
        .padding()
        .frame(width: 480)
}
