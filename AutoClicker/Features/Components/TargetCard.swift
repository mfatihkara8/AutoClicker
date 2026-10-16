import SwiftUI

/// Where each click lands: the current cursor, or a fixed point entered by hand or captured with Pick Location.
struct TargetCard: View {
    @Binding var target: ClickTarget
    /// The remaining Pick Location countdown seconds, or `nil` when no pick is in progress.
    let pickLocationCountdown: Int?
    /// Whether the engine is skipping clicks because the target lies inside the app's own window.
    let isTargetInsideOwnWindow: Bool
    let onPickLocation: () -> Void
    let onCancelPickLocation: () -> Void

    /// The last fixed point seen, so switching to the cursor and back does not lose a picked location.
    @State private var lastFixedPoint: CGPoint = .zero

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Target", selection: editor.kind) {
                    Text("Current cursor").tag(ClickTargetEditor.Kind.currentCursor)
                    Text("Fixed position").tag(ClickTargetEditor.Kind.fixed)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("targetKindPicker")

                if editor.wrappedValue.kind == .fixed {
                    fixedPositionFields
                } else {
                    Text("Each click lands wherever the cursor is at that moment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                pickLocationRow

                if isTargetInsideOwnWindow {
                    WarningLabel("Move the cursor outside the AutoClicker window to start clicking.")
                }
            }
            .padding(4)
        } label: {
            Label("Target", systemImage: "scope")
                .font(.headline)
        }
        .onChange(of: target, initial: true) { _, newTarget in
            if case .fixed(let point) = newTarget {
                lastFixedPoint = point
            }
        }
    }

    private var fixedPositionFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                coordinateField("X", title: "X coordinate", value: editor.x, identifier: "targetX")
                coordinateField("Y", title: "Y coordinate", value: editor.y, identifier: "targetY")
            }
            Text("Screen coordinates in points, measured from the top-left corner of the main display.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func coordinateField(
        _ label: LocalizedStringKey, title: LocalizedStringKey, value: Binding<Int>, identifier: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
            NumberField(
                title: title, value: value, range: ClickTargetEditor.coordinateRange, fieldWidth: 64,
                identifier: identifier)
        }
    }

    @ViewBuilder private var pickLocationRow: some View {
        HStack {
            if let pickLocationCountdown {
                Label {
                    Text("Move the cursor to the target. Picking in \(pickLocationCountdown)…")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "hourglass")
                }
                .accessibilityIdentifier("pickLocationCountdown")
                Spacer()
                Button("Cancel", action: onCancelPickLocation)
                    .accessibilityIdentifier("cancelPickLocationButton")
            } else {
                Button("Pick Location", systemImage: "scope", action: onPickLocation)
                    .help("Captures the cursor position as a fixed target after a 3-second countdown")
                    .accessibilityIdentifier("pickLocationButton")
                Spacer()
            }
        }
    }

    /// Routes every control through the editor, which clamps the input before it reaches the configuration.
    private var editor: Binding<ClickTargetEditor> {
        Binding(
            get: { ClickTargetEditor(target: target, fallbackPoint: lastFixedPoint) },
            set: { target = $0.target }
        )
    }
}

#Preview("Cursor") {
    @Previewable @State var target = ClickTarget.currentCursor
    TargetCard(
        target: $target, pickLocationCountdown: nil, isTargetInsideOwnWindow: false,
        onPickLocation: {}, onCancelPickLocation: {}
    )
    .padding()
    .frame(width: 480)
}

#Preview("Fixed, picking") {
    @Previewable @State var target = ClickTarget.fixed(CGPoint(x: 640, y: 400))
    TargetCard(
        target: $target, pickLocationCountdown: 2, isTargetInsideOwnWindow: true,
        onPickLocation: {}, onCancelPickLocation: {}
    )
    .padding()
    .frame(width: 480)
}
