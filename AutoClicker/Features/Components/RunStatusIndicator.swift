import SwiftUI

/// The toolbar's non-interactive run state: a gray dot and "Idle", or a green dot and "Active" (SPEC §3.5).
///
/// Plain content, not a button, so it has no hover or click affordance. It shows no click count, which would make it
/// change width several times a second while clicking.
struct RunStatusIndicator: View {
    let isRunning: Bool

    var body: some View {
        let presentation = ToolbarRunPresentation(isRunning: isRunning, canStart: true, toggleHotkeyName: nil)
        HStack(spacing: 5) {
            Circle()
                .fill(isRunning ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            Text(presentation.statusText)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .fixedSize()
        // One element for VoiceOver, read as its text; the dot only repeats it in color.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.statusText)
        .accessibilityIdentifier("toolbarStatusIndicator")
    }
}

#Preview {
    HStack(spacing: 24) {
        RunStatusIndicator(isRunning: false)
        RunStatusIndicator(isRunning: true)
    }
    .padding()
}
