import SwiftUI

/// The run status: the Active/Inactive indicator, the total click counter with Reset, the Start/Stop button and why
/// the last run ended.
struct StatusCard: View {
    let isRunning: Bool
    let canStart: Bool
    let totalClicks: Int
    /// The already localized stop reason, or `nil` to show none.
    let lastStopReason: String?
    let onStart: () -> Void
    let onStop: () -> Void
    let onResetCounter: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    statusIndicator
                    Spacer()
                    counter
                    Button("Reset", systemImage: "arrow.counterclockwise", action: onResetCounter)
                        .help("Set the total click counter back to zero")
                        .accessibilityIdentifier("resetCounterButton")
                }

                startStopButton

                if let lastStopReason {
                    Label(lastStopReason, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("lastStopReason")
                }
            }
            .padding(4)
        } label: {
            Label("Status", systemImage: "power")
                .font(.headline)
        }
    }

    private var statusIndicator: some View {
        Label {
            Text(isRunning ? "Active" : "Inactive")
                .font(.title3.weight(.semibold))
        } icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(isRunning ? .green : .secondary)
                .symbolEffect(.pulse, isActive: isRunning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("statusLabel")
    }

    private var counter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("Total clicks")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(totalClicks, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("Total clicks")
                .accessibilityValue(Text(totalClicks, format: .number))
                .accessibilityIdentifier("totalClicks")
        }
    }

    private var startStopButton: some View {
        // Start and Stop call different intents: Stop must report `.user`, while the F6 toggle reports `.hotkey`.
        // No default keyboard shortcut: Return commits the number fields and must never start clicking.
        Button(action: isRunning ? onStop : onStart) {
            Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(isRunning ? Color.red : Color.accentColor)
        .disabled(!isRunning && !canStart)
        .help(startStopHelp)
        .accessibilityIdentifier("startStopButton")
    }

    private var startStopHelp: LocalizedStringKey {
        if isRunning {
            "Stop clicking (F6 or Esc)"
        } else if canStart {
            "Start clicking (F6)"
        } else {
            "Grant Accessibility permission to start clicking"
        }
    }
}

#Preview("Idle") {
    StatusCard(
        isRunning: false, canStart: true, totalClicks: 1_234, lastStopReason: StopReason.hotkey.displayText,
        onStart: {}, onStop: {}, onResetCounter: {}
    )
    .padding()
    .frame(width: 480)
}

#Preview("Running") {
    StatusCard(
        isRunning: true, canStart: true, totalClicks: 98_765, lastStopReason: nil,
        onStart: {}, onStop: {}, onResetCounter: {}
    )
    .padding()
    .frame(width: 480)
}

#Preview("No permission") {
    StatusCard(
        isRunning: false, canStart: false, totalClicks: 0, lastStopReason: nil,
        onStart: {}, onStop: {}, onResetCounter: {}
    )
    .padding()
    .frame(width: 480)
}
