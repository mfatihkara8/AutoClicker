import SwiftUI

/// The Shortcuts tab: the configurable start/stop shortcut and the fixed Esc emergency stop (SPEC §3.5).
///
/// Change… and Reset are disabled while clicking, like every other setting. Cancel stays enabled so a recording can
/// always be ended.
struct ShortcutsTab: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        Form {
            Section("Start and stop") {
                LabeledContent {
                    HStack(spacing: 8) {
                        if viewModel.isRecordingShortcut {
                            recordingControls
                        } else {
                            shortcutControls
                        }
                    }
                } label: {
                    Text("Shortcut")
                    Text("Works in every app. F1–F20 work alone; other keys need ⌘, ⌥ or ⌃.")
                }

                if let warning = viewModel.shortcutWarning {
                    WarningLabel(verbatim: warning)
                        .accessibilityIdentifier("shortcutWarning")
                }
                if let warning = viewModel.hotkeyWarning {
                    WarningLabel(verbatim: warning)
                        .accessibilityIdentifier("hotkeyWarning")
                }
            }

            Section("Emergency stop") {
                LabeledContent {
                    KeyCap("Esc")
                        .accessibilityIdentifier("emergencyStopKey")
                } label: {
                    Text("Stop clicking")
                    Text("Works only while clicking, so Esc stays free in other apps.")
                }

                if let warning = viewModel.emergencyStopWarning {
                    WarningLabel(verbatim: warning)
                        .accessibilityIdentifier("emergencyStopWarning")
                }
            }
        }
        .formStyle(.grouped)
        // The recorder sees every key sent to this window, so a recording must not outlive the tab that shows it.
        .onDisappear(perform: viewModel.cancelRecordingShortcut)
    }

    @ViewBuilder private var shortcutControls: some View {
        let name = viewModel.toggleHotkey.displayName
        KeyCap(verbatim: name)
            .accessibilityLabel(Text("Start/stop shortcut"))
            .accessibilityValue(Text(verbatim: name))
            .accessibilityIdentifier("shortcutName")
        Button("Change…", action: viewModel.beginRecordingShortcut)
            .disabled(!viewModel.canChangeShortcut)
            .help("Record a new start/stop shortcut")
            .accessibilityIdentifier("changeShortcutButton")
        Button("Reset", action: viewModel.resetShortcut)
            .disabled(!viewModel.canChangeShortcut || viewModel.isDefaultShortcut)
            .help("Go back to F6")
            .accessibilityIdentifier("resetShortcutButton")
    }

    @ViewBuilder private var recordingControls: some View {
        Text("Press a key combination… Esc to cancel")
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("shortcutRecordingPrompt")
        // Esc never reaches this button while recording: the recorder captures it and cancels.
        Button("Cancel", action: viewModel.cancelRecordingShortcut)
            .accessibilityIdentifier("cancelShortcutButton")
    }
}
