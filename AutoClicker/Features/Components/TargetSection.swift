import SwiftUI

/// The Click tab's "Target" section: the current cursor, a fixed point entered by hand or captured with Pick Location,
/// or a sequence of points edited in a sheet.
///
/// Every mode stays at most four rows tall, so the right column of the Click tab fits the default window size. Notes
/// that would widen a row's label sit in the footer instead.
struct TargetSection: View {
    @Binding var target: ClickTarget
    /// The last fixed point and point list, which come back when switching kinds.
    let memory: ClickTargetMemory
    /// The remaining Pick Location countdown seconds for the fixed target, or `nil` when no such pick is in progress.
    let pickLocationCountdown: Int?
    /// Whether the engine is skipping clicks because the target lies inside the app's own window.
    let isTargetInsideOwnWindow: Bool
    /// Everything the Edit Points sheet needs besides the points.
    let sequencePicking: SequencePointPicking
    let onPickLocation: () -> Void
    let onCancelPickLocation: () -> Void

    @State private var isEditingPoints = false

    var body: some View {
        Section {
            Picker("Click at", selection: editor.kind) {
                Text("Cursor").tag(ClickTargetEditor.Kind.currentCursor)
                Text("Fixed").tag(ClickTargetEditor.Kind.fixed)
                Text("Sequence").tag(ClickTargetEditor.Kind.sequence)
            }
            .pickerStyle(.segmented)
            // A finished pick sets a fixed target, so switching kinds meanwhile would be overridden a moment later.
            .disabled(pickLocationCountdown != nil)
            .accessibilityIdentifier("targetKindPicker")

            switch kind {
            case .currentCursor:
                pickLocationRow
            case .fixed:
                LabeledContent {
                    HStack(spacing: 12) {
                        coordinateField("X", title: "X coordinate", value: editor.x, identifier: "targetX")
                        coordinateField("Y", title: "Y coordinate", value: editor.y, identifier: "targetY")
                    }
                } label: {
                    Text("Position")
                }
                pickLocationRow
            case .sequence:
                LabeledContent {
                    Button("Edit Points…") {
                        isEditingPoints = true
                    }
                    .accessibilityIdentifier("editPointsButton")
                } label: {
                    pointCountText
                        .accessibilityIdentifier("sequencePointCount")
                }
            }

            if isTargetInsideOwnWindow {
                WarningLabel("Move the cursor outside the AutoClicker window to start clicking.")
            }
        } header: {
            Text("Target")
        } footer: {
            // A footer rather than a subtitle, which would push X and Y onto a second line in the narrow column.
            switch kind {
            case .currentCursor:
                EmptyView()
            case .fixed:
                // CG global points (ADR-006): what X and Y store, and what the user knows as screen coordinates.
                Text("X and Y are points from the top-left of the main display.")
            case .sequence:
                Text("Clicks the points in order, each after its own delay, then starts over.")
            }
        }
        .sheet(isPresented: $isEditingPoints) {
            SequenceEditorSheet(points: editor.sequencePoints, picking: sequencePicking)
        }
        .onChange(of: kind) { _, newKind in
            // A profile applied from the menu bar can change the target while the sheet is open.
            if newKind != .sequence {
                isEditingPoints = false
            }
        }
    }

    private var pickLocationRow: some View {
        LabeledContent {
            if pickLocationCountdown == nil {
                Button("Pick Location", systemImage: "scope", action: onPickLocation)
                    .help("Captures the cursor position as a fixed target after a 3-second countdown")
                    .accessibilityIdentifier("pickLocationButton")
            } else {
                Button("Cancel", action: onCancelPickLocation)
                    .accessibilityIdentifier("cancelPickLocationButton")
            }
        } label: {
            pickLocationLabel
        }
    }

    @ViewBuilder private var pickLocationLabel: some View {
        if let pickLocationCountdown {
            Label {
                Text("Picking in \(pickLocationCountdown)…")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "hourglass")
            }
            .accessibilityIdentifier("pickLocationCountdown")
            Text("Move the cursor to the target.")
        } else {
            Text("Pick on screen")
            Text("Captures the cursor in \(MainViewModel.pickLocationCountdownStart) s.")
        }
    }

    private var pointCountText: Text {
        let count = editor.wrappedValue.sequencePoints.count
        return switch count {
        case 0: Text("No points yet")
        case 1: Text("1 point")
        default: Text("\(count) points")
        }
    }

    private func coordinateField(
        _ label: LocalizedStringKey, title: LocalizedStringKey, value: Binding<Int>, identifier: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            NumberField(
                title: title, value: value, range: ClickTargetEditor.coordinateRange, fieldWidth: 56,
                identifier: identifier)
        }
    }

    private var kind: ClickTargetEditor.Kind {
        editor.wrappedValue.kind
    }

    /// Routes every target control through the editor, which clamps the input before it reaches the configuration.
    private var editor: Binding<ClickTargetEditor> {
        Binding(
            get: { ClickTargetEditor(target: target, memory: memory) },
            set: { target = $0.target }
        )
    }
}

#Preview("Cursor") {
    @Previewable @State var target = ClickTarget.currentCursor
    Form {
        TargetSection(
            target: $target, memory: ClickTargetMemory(), pickLocationCountdown: nil,
            isTargetInsideOwnWindow: false, sequencePicking: .preview, onPickLocation: {}, onCancelPickLocation: {})
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

#Preview("Fixed, picking") {
    @Previewable @State var target = ClickTarget.fixed(CGPoint(x: 640, y: 400))
    Form {
        TargetSection(
            target: $target, memory: ClickTargetMemory(), pickLocationCountdown: 2,
            isTargetInsideOwnWindow: true, sequencePicking: .preview, onPickLocation: {}, onCancelPickLocation: {})
    }
    .formStyle(.grouped)
    .frame(width: 380)
}

#Preview("Sequence") {
    @Previewable @State var target = ClickTarget.sequence([
        ClickPoint(point: CGPoint(x: 100, y: 200), delayMilliseconds: 100),
        ClickPoint(point: CGPoint(x: 300, y: 400), delayMilliseconds: 250),
    ])
    Form {
        TargetSection(
            target: $target, memory: ClickTargetMemory(), pickLocationCountdown: nil,
            isTargetInsideOwnWindow: false, sequencePicking: .preview, onPickLocation: {}, onCancelPickLocation: {})
    }
    .formStyle(.grouped)
    .frame(width: 380)
}
