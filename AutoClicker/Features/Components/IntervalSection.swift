import SwiftUI

/// The Click tab's "Interval" section: the time between clicks as hours, minutes, seconds and milliseconds, and a ±
/// jitter.
///
/// The notes are a subtitle and a footer rather than rows of their own, so the section stays two rows tall.
struct IntervalSection: View {
    @Binding var interval: ClickInterval

    var body: some View {
        Section {
            LabeledContent {
                HStack(spacing: 8) {
                    NumberField(
                        title: "Hours", value: editor.hours, range: ClickIntervalEditor.hoursRange, unit: "h",
                        fieldWidth: 36, showsStepper: false,
                        identifier: "intervalHours")
                    NumberField(
                        title: "Minutes", value: editor.minutes, range: ClickIntervalEditor.minutesRange,
                        unit: "min", fieldWidth: 36, showsStepper: false,
                        identifier: "intervalMinutes")
                    NumberField(
                        title: "Seconds", value: editor.seconds, range: ClickIntervalEditor.secondsRange,
                        unit: "s", fieldWidth: 36, showsStepper: false,
                        identifier: "intervalSeconds")
                    NumberField(
                        title: "Milliseconds", value: editor.milliseconds,
                        range: ClickIntervalEditor.millisecondsRange, unit: "ms", showsStepper: false,
                        identifier: "intervalMilliseconds")
                }
            } label: {
                Text("Every")
            }

            LabeledContent {
                HStack(spacing: 4) {
                    Text(verbatim: "±")
                        .foregroundStyle(.secondary)
                    NumberField(
                        title: "Jitter in milliseconds", value: editor.jitterMilliseconds,
                        range: ClickIntervalEditor.jitterRange, unit: "ms", fieldWidth: 64,
                        identifier: "jitterMilliseconds")
                }
            } label: {
                Text("Jitter")
                jitterNote
            }
        } header: {
            Text("Interval")
        } footer: {
            // A footer rather than a subtitle, which would push the four fields onto a second line.
            if state.isRaisedToMinimum {
                WarningLabel("An interval of 0 is raised to the 1 ms minimum.")
            } else {
                Text("The shortest interval is 1 ms.")
            }
        }
    }

    @ViewBuilder private var jitterNote: some View {
        if state.isJitterCapped {
            if state.effectiveJitterMilliseconds == 0 {
                WarningLabel("Off: interval too short.")
            } else {
                WarningLabel("Capped at ±\(state.effectiveJitterMilliseconds) ms.")
            }
        } else {
            Text("Shifts each click randomly.")
        }
    }

    private var state: ClickIntervalEditor {
        ClickIntervalEditor(interval: interval)
    }

    /// Routes every field through the editor, which clamps the input before it reaches the configuration.
    private var editor: Binding<ClickIntervalEditor> {
        Binding(
            get: { ClickIntervalEditor(interval: interval) },
            set: { interval = $0.interval }
        )
    }
}

#Preview("Default") {
    @Previewable @State var interval = ClickInterval(milliseconds: 100)
    Form {
        IntervalSection(interval: $interval)
    }
    .formStyle(.grouped)
    .frame(width: 540)
}

#Preview("Capped jitter") {
    @Previewable @State var interval = ClickInterval(milliseconds: 20, jitterMilliseconds: 50)
    Form {
        IntervalSection(interval: $interval)
    }
    .formStyle(.grouped)
    .frame(width: 540)
}
