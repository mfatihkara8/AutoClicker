import SwiftUI

/// The Main tab: status, counter, Start/Stop, a settings summary, the last stop reason, warnings and the shortcut hint,
/// top to bottom (SPEC §3.5).
///
/// It only shows and runs; editing happens on the Click and Shortcuts tabs. It is laid out to fit the default window
/// size, with the permission banner shown above it, so it never scrolls.
struct MainTab: View {
    let viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 14) {
            statusLabel
            counter
            StartStopButton(
                size: .large,
                isRunning: viewModel.isRunning,
                canStart: viewModel.canStart,
                toggleHotkeyName: viewModel.advertisedToggleHotkeyName,
                onStart: viewModel.start,
                onStop: viewModel.stop
            )
            .frame(maxWidth: 280)
            .accessibilityIdentifier("startStopButton")

            settingsSummary

            if !viewModel.isRunning, let reason = viewModel.lastStopReason {
                Label(reason.displayText, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("lastStopReason")
            }

            warnings

            shortcutHint
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusLabel: some View {
        let isRunning = viewModel.isRunning
        return Label {
            Text(isRunning ? "Active" : "Inactive")
                .font(.title3.weight(.semibold))
        } icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(isRunning ? Color.green : Color.secondary)
                .symbolEffect(.pulse, isActive: isRunning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("statusLabel")
    }

    private var counter: some View {
        VStack(spacing: 2) {
            Text(viewModel.totalClicks, format: .number)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel("Total clicks")
                .accessibilityValue(Text(viewModel.totalClicks, format: .number))
                .accessibilityIdentifier("totalClicks")
            HStack(spacing: 8) {
                Text("Total clicks")
                    .foregroundStyle(.secondary)
                Button("Reset", systemImage: "arrow.counterclockwise", action: viewModel.resetCounter)
                    .buttonStyle(.borderless)
                    .help("Set the total click counter back to zero")
                    .accessibilityIdentifier("resetCounterButton")
            }
            .font(.callout)
        }
    }

    private var settingsSummary: some View {
        let summary = SettingsSummary(configuration: viewModel.configuration).text
        return Text(verbatim: summary)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            // The full line, in case a long fixed point or duration makes it truncate.
            .help(Text(verbatim: summary))
            .accessibilityLabel(Text("Settings: \(summary)"))
            .accessibilityIdentifier("settingsSummary")
    }

    private var warnings: some View {
        VStack(spacing: 6) {
            if viewModel.isTargetInsideOwnWindow {
                WarningLabel("Move the cursor outside the AutoClicker window to start clicking.")
                    .accessibilityIdentifier("ownWindowWarning")
            }
            if let hotkeyWarning = viewModel.hotkeyWarning {
                WarningLabel(verbatim: hotkeyWarning)
                    .accessibilityIdentifier("hotkeyWarning")
            }
            if let emergencyStopWarning = viewModel.emergencyStopWarning {
                WarningLabel(verbatim: emergencyStopWarning)
                    .accessibilityIdentifier("emergencyStopWarning")
            }
        }
        // Long warnings wrap into a readable column instead of spanning a widened window.
        .frame(maxWidth: 440)
    }

    private var shortcutHint: some View {
        HStack(spacing: 16) {
            // Not advertised while it could not be registered; the hotkey warning above explains why.
            if let toggleName = viewModel.advertisedToggleHotkeyName {
                hint(KeyCap(verbatim: toggleName), action: "Start/Stop")
            }
            hint(KeyCap("Esc"), action: "Stop")
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hotkeyHint")
    }

    private func hint(_ key: KeyCap, action: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            key
            Text(action)
                .foregroundStyle(.secondary)
        }
    }
}
