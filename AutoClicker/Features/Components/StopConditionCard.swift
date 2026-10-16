import SwiftUI

/// When a run ends on its own: never, after a number of clicks or after a duration.
struct StopConditionCard: View {
    @Binding var stopCondition: StopCondition

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Stop", selection: editor.kind) {
                    Text("Never").tag(StopConditionEditor.Kind.never)
                    Text("After clicks").tag(StopConditionEditor.Kind.afterClicks)
                    Text("After time").tag(StopConditionEditor.Kind.afterDuration)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("stopConditionPicker")

                switch editor.wrappedValue.kind {
                case .never:
                    caption("Runs until you stop it with Stop, the start/stop shortcut or Esc.")
                case .afterClicks:
                    HStack(spacing: 6) {
                        Text("Stop after")
                        NumberField(
                            title: "Number of clicks", value: editor.clicks, range: StopConditionEditor.clicksRange,
                            unit: "clicks", fieldWidth: 88, identifier: "stopAfterClicks")
                    }
                case .afterDuration:
                    HStack(spacing: 10) {
                        Text("Stop after")
                        NumberField(
                            title: "Hours", value: editor.hours, range: StopConditionEditor.hoursRange, unit: "h",
                            identifier: "stopAfterHours")
                        NumberField(
                            title: "Minutes", value: editor.minutes, range: StopConditionEditor.minutesRange,
                            unit: "min", identifier: "stopAfterMinutes")
                        NumberField(
                            title: "Seconds", value: editor.seconds, range: StopConditionEditor.secondsRange,
                            unit: "s", identifier: "stopAfterSeconds")
                    }
                }
            }
            .padding(4)
        } label: {
            Label("Stop Condition", systemImage: "flag.checkered")
                .font(.headline)
        }
    }

    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Routes every control through the editor, which clamps the input before it reaches the configuration.
    private var editor: Binding<StopConditionEditor> {
        Binding(
            get: { StopConditionEditor(condition: stopCondition) },
            set: { stopCondition = $0.condition }
        )
    }
}

#Preview("After clicks") {
    @Previewable @State var condition = StopCondition.afterClicks(500)
    StopConditionCard(stopCondition: $condition)
        .padding()
        .frame(width: 480)
}

#Preview("After time") {
    @Previewable @State var condition = StopCondition.afterDuration(.seconds(90))
    StopConditionCard(stopCondition: $condition)
        .padding()
        .frame(width: 480)
}
