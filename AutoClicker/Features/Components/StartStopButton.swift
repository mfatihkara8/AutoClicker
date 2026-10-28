import SwiftUI

/// The Start/Stop control, either as the big button on the Main tab or as the compact toolbar button with a status dot
/// shown on every tab.
///
/// Start and Stop call different intents: Stop must report `.user`, while the shortcut reports `.hotkey`. There is no
/// default keyboard shortcut, because Return commits the number fields and must never start clicking.
struct StartStopButton: View {
    enum Size {
        /// Full width and prominent, for the Main tab.
        case large
        /// Small, with a status dot, for the toolbar.
        case compact
    }

    let size: Size
    let isRunning: Bool
    let canStart: Bool
    /// The start/stop shortcut for the help text, or `nil` when it is not registered.
    let toggleHotkeyName: String?
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        switch size {
        case .large:
            Button(action: action) {
                Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isRunning ? Color.red : Color.accentColor)
            .disabled(!isRunning && !canStart)
            .help(help)
        case .compact:
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(isRunning ? Color.green : Color.secondary)
                        .accessibilityHidden(true)
                    Text(isRunning ? "Stop" : "Start")
                }
            }
            .disabled(!isRunning && !canStart)
            .help(help)
            // The dot is hidden from VoiceOver, so the state it shows is read as the value instead.
            .accessibilityValue(Text(isRunning ? "Active" : "Inactive"))
        }
    }

    private var action: () -> Void {
        isRunning ? onStop : onStart
    }

    private var help: LocalizedStringKey {
        switch (isRunning, toggleHotkeyName) {
        case (true, let shortcut?):
            "Stop clicking (\(shortcut) or Esc)"
        case (true, nil):
            "Stop clicking (Esc)"
        case (false, let shortcut?) where canStart:
            "Start clicking (\(shortcut))"
        case (false, nil) where canStart:
            "Start clicking"
        default:
            "Grant Accessibility permission to start clicking"
        }
    }
}

#Preview("Large") {
    VStack {
        StartStopButton(
            size: .large, isRunning: false, canStart: true, toggleHotkeyName: "F6", onStart: {}, onStop: {})
        StartStopButton(
            size: .large, isRunning: true, canStart: true, toggleHotkeyName: "F6", onStart: {}, onStop: {})
    }
    .padding()
    .frame(width: 280)
}

#Preview("Compact") {
    HStack {
        StartStopButton(
            size: .compact, isRunning: false, canStart: true, toggleHotkeyName: "F6", onStart: {}, onStop: {})
        StartStopButton(
            size: .compact, isRunning: true, canStart: true, toggleHotkeyName: "F6", onStart: {}, onStop: {})
    }
    .padding()
}
