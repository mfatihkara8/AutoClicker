import SwiftUI

/// The time between clicks as hours, minutes, seconds and milliseconds, plus a ± jitter.
struct IntervalCard: View {
    @Binding var interval: ClickInterval

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Every")
                            .gridColumnAlignment(.trailing)
                        HStack(spacing: 10) {
                            NumberField(
                                title: "Hours", value: editor.hours, range: ClickIntervalEditor.hoursRange,
                                unit: "h", identifier: "intervalHours")
                            NumberField(
                                title: "Minutes", value: editor.minutes, range: ClickIntervalEditor.minutesRange,
                                unit: "min", identifier: "intervalMinutes")
                            NumberField(
                                title: "Seconds", value: editor.seconds, range: ClickIntervalEditor.secondsRange,
                                unit: "s", identifier: "intervalSeconds")
                            NumberField(
                                title: "Milliseconds", value: editor.milliseconds,
                                range: ClickIntervalEditor.millisecondsRange, unit: "ms",
                                identifier: "intervalMilliseconds"
                            )
                        }
                    }
                    GridRow {
                        Text("Jitter")
                        HStack(spacing: 4) {
                            Text(verbatim: "±")
                                .foregroundStyle(.secondary)
                            NumberField(
                                title: "Jitter in milliseconds", value: editor.jitterMilliseconds,
                                range: ClickIntervalEditor.jitterRange, unit: "ms", fieldWidth: 64,
                                identifier: "jitterMilliseconds")
                        }
                    }
                }

                notes
            }
            .padding(4)
        } label: {
            Label("Interval", systemImage: "timer")
                .font(.headline)
        }
    }

    @ViewBuilder private var notes: some View {
        let state = ClickIntervalEditor(interval: interval)
        if state.isJitterCapped {
            if state.effectiveJitterMilliseconds == 0 {
                WarningLabel("Jitter is off because the interval is too short.")
            } else {
                WarningLabel(
                    "Jitter is limited to ±\(state.effectiveJitterMilliseconds) ms so clicks stay at least 1 ms apart."
                )
            }
        }
        if state.isRaisedToMinimum {
            WarningLabel("An interval of 0 is raised to the 1 ms minimum.")
        } else {
            Text("The shortest interval is 1 ms. Jitter randomly shifts each click by up to the given amount.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
    IntervalCard(interval: $interval)
        .padding()
        .frame(width: 480)
}

#Preview("Capped jitter") {
    @Previewable @State var interval = ClickInterval(milliseconds: 20, jitterMilliseconds: 50)
    IntervalCard(interval: $interval)
        .padding()
        .frame(width: 480)
}
