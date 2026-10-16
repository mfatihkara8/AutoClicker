import SwiftUI

/// The keyboard shortcuts, plus any warning about a hotkey that could not be registered.
struct HotkeyHint: View {
    /// Already localized by the view model, so shown verbatim.
    let hotkeyWarning: String?
    /// Already localized by the view model, so shown verbatim.
    let emergencyStopWarning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                shortcut(key: "F6", action: "Start/Stop")
                shortcut(key: "Esc", action: "Stop (while clicking)")
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

    private func shortcut(key: LocalizedStringKey, action: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.callout.monospaced().weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(action)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Hint") {
    HotkeyHint(hotkeyWarning: nil, emergencyStopWarning: nil)
        .padding()
        .frame(width: 480)
}

#Preview("Warnings") {
    HotkeyHint(
        hotkeyWarning: "F6 is used by another app. Use the Start button instead.",
        emergencyStopWarning: "Esc is unavailable as an emergency stop. Use F6, the Stop button or a screen corner."
    )
    .padding()
    .frame(width: 480)
}
