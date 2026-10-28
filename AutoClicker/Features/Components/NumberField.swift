import SwiftUI

/// A compact integer field with an optional stepper and unit, used by every settings section.
///
/// It holds no validation of its own: the binding it gets comes from one of the editor types, which clamp every value.
/// The text field only writes to the binding when its text parses, so clearing it and committing never stores
/// anything.
struct NumberField: View {
    /// The accessibility label; the visible label is the unit or the surrounding form row.
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: LocalizedStringKey?
    var fieldWidth: CGFloat = 44
    /// Rows of several time components (h, min, s, ms) leave the steppers out so they fit on one line in a
    /// Click tab column.
    var showsStepper = true
    let identifier: String

    var body: some View {
        HStack(spacing: 2) {
            TextField(title, value: $value, format: .number.grouping(.never))
                .labelsHidden()
                // A grouped form draws fields borderless by default, which makes them look like plain values.
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: fieldWidth)
                .accessibilityIdentifier(identifier)
            if showsStepper {
                Stepper(title, value: $value, in: range)
                    .labelsHidden()
                    .accessibilityIdentifier("\(identifier)Stepper")
            }
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                    .accessibilityHidden(true)
            }
        }
        // A form row squeezes its content before its label, which would truncate the unit to "…".
        .fixedSize()
    }
}

#Preview {
    @Previewable @State var value = 100
    NumberField(title: "Milliseconds", value: $value, range: 0...999, unit: "ms", identifier: "preview")
        .padding()
}
