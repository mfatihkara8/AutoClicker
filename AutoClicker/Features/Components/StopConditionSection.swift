import SwiftUI

/// The Click tab's "Stop" section: never, after a number of clicks or after a duration.
///
/// The value row appears only for the kinds that have a value, so "Never" costs a single row.
struct StopConditionSection: View {
    @Binding var stopCondition: StopCondition

    var body: some View {
        Section("Stop") {
            Picker("Ends", selection: editor.kind) {
                Text("Never").tag(StopConditionEditor.Kind.never)
                Text("After clicks").tag(StopConditionEditor.Kind.afterClicks)
                Text("After time").tag(StopConditionEditor.Kind.afterDuration)
            }
            // A menu: three segments do not fit beside the label in a Click tab column.
            .pickerStyle(.menu)
            .accessibilityIdentifier("stopConditionPicker")

            switch editor.wrappedValue.kind {
            case .never:
                EmptyView()
            case .afterClicks:
                LabeledContent("Clicks") {
                    NumberField(
                        title: "Number of clicks", value: editor.clicks, range: StopConditionEditor.clicksRange,
                        unit: "clicks", fieldWidth: 88, identifier: "stopAfterClicks")
                }
            case .afterDuration:
                LabeledContent("Duration") {
                    HStack(spacing: 8) {
                        NumberField(
                            title: "Hours", value: editor.hours, range: StopConditionEditor.hoursRange, unit: "h",
                            fieldWidth: 36, showsStepper: false,
                            identifier: "stopAfterHours")
                        NumberField(
                            title: "Minutes", value: editor.minutes, range: StopConditionEditor.minutesRange,
                            unit: "min", fieldWidth: 36, showsStepper: false,
                            identifier: "stopAfterMinutes")
                        NumberField(
                            title: "Seconds", value: editor.seconds, range: StopConditionEditor.secondsRange,
                            unit: "s", fieldWidth: 36, showsStepper: false,
                            identifier: "stopAfterSeconds")
                    }
                }
            }
        }
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
    Form {
        StopConditionSection(stopCondition: $condition)
    }
    .formStyle(.grouped)
    .frame(width: 540)
}

#Preview("After time") {
    @Previewable @State var condition = StopCondition.afterDuration(.seconds(90))
    Form {
        StopConditionSection(stopCondition: $condition)
    }
    .formStyle(.grouped)
    .frame(width: 540)
}
