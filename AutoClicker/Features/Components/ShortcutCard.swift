import SwiftUI

/// The start/stop shortcut: the current shortcut with Change… and Reset, or the recording prompt (SPEC §3.3).
///
/// The main window disables it with the other settings while clicking.
struct ShortcutCard: View {
    /// The display name of the current start/stop shortcut, such as "F6" or "⌃⌥K".
    let shortcutName: String
    /// Whether the next key press becomes the new shortcut.
    let isRecording: Bool
    /// Whether the shortcut is already F6, so Reset has nothing to do.
    let isDefault: Bool
    /// Why the last change did not happen. Already localized by the view model, so shown verbatim.
    let warning: String?
    let onChange: () -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Start/Stop")
                    Spacer(minLength: 8)
                    if isRecording {
                        recordingControls
                    } else {
                        shortcutControls
                    }
                }

                if let warning {
                    WarningLabel(verbatim: warning)
                        .accessibilityIdentifier("shortcutWarning")
                }

                Text("Works in every app. F1–F20 work alone; other keys need ⌘, ⌥ or ⌃. Esc always stops clicking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(4)
        } label: {
            Label("Keyboard Shortcut", systemImage: "keyboard")
                .font(.headline)
        }
    }

    @ViewBuilder private var shortcutControls: some View {
        KeyCap(verbatim: shortcutName)
            .accessibilityLabel(Text("Start/stop shortcut"))
            .accessibilityValue(Text(verbatim: shortcutName))
            .accessibilityIdentifier("shortcutName")
        Button("Change…", action: onChange)
            .help("Record a new start/stop shortcut")
            .accessibilityIdentifier("changeShortcutButton")
        Button("Reset", action: onReset)
            .disabled(isDefault)
            .help("Go back to F6")
            .accessibilityIdentifier("resetShortcutButton")
    }

    @ViewBuilder private var recordingControls: some View {
        Text("Press a key combination… Esc to cancel")
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("shortcutRecordingPrompt")
        // Esc never reaches this button while recording: the recorder captures it and cancels.
        Button("Cancel", action: onCancel)
            .accessibilityIdentifier("cancelShortcutButton")
    }
}

#Preview("Default") {
    ShortcutCard(
        shortcutName: "F6", isRecording: false, isDefault: true, warning: nil, onChange: {}, onCancel: {},
        onReset: {}
    )
    .padding()
    .frame(width: 480)
}

#Preview("Recording") {
    ShortcutCard(
        shortcutName: "F6", isRecording: true, isDefault: true, warning: nil, onChange: {}, onCancel: {}, onReset: {}
    )
    .padding()
    .frame(width: 480)
}

#Preview("Custom with warning") {
    ShortcutCard(
        shortcutName: "⌃⌥K", isRecording: false, isDefault: false,
        warning: "This shortcut is in use by another app. Keeping ⌃⌥K.", onChange: {}, onCancel: {}, onReset: {}
    )
    .padding()
    .frame(width: 480)
}
