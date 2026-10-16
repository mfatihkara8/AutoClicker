import SwiftUI

/// The keyboard shortcuts, plus any warning about a hotkey that could not be registered.
struct HotkeyHint: View {
    /// The display name of the current start/stop shortcut, such as "F6" or "⌃⌥K".
    let toggleHotkeyName: String
    /// Already localized by the view model, so shown verbatim.
    let hotkeyWarning: String?
    /// Already localized by the view model, so shown verbatim.
    let emergencyStopWarning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                shortcut(KeyCap(verbatim: toggleHotkeyName), action: "Start/Stop")
                shortcut(KeyCap("Esc"), action: "Stop (while clicking)")
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("hotkeyHint")

            if let hotkeyWarning {
                WarningLabel(verbatim: hotkeyWarning)
                    .accessibilityIdentifier("hotkeyWarning")
            }
            if let emergencyStopWarning {
                WarningLabel(verbatim: emergencyStopWarning)
                    .accessibilityIdentifier("emergencyStopWarning")
            }
        }
        .font(.callout)
    }

    private func shortcut(_ key: KeyCap, action: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            key
            Text(action)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Hint") {
    HotkeyHint(toggleHotkeyName: "F6", hotkeyWarning: nil, emergencyStopWarning: nil)
        .padding()
        .frame(width: 480)
}

#Preview("Custom shortcut with warnings") {
    HotkeyHint(
        toggleHotkeyName: "⌃⌥K",
        hotkeyWarning: "⌃⌥K is used by another app. Use the Start button instead.",
        emergencyStopWarning: "Esc is unavailable as an emergency stop. Use ⌃⌥K, the Stop button or a screen corner."
    )
    .padding()
    .frame(width: 480)
}
