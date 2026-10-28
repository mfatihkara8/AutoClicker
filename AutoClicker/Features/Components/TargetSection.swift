import SwiftUI

/// The Click tab's "Target" section: the current cursor, or a fixed point entered by hand or captured with Pick
/// Location.
///
/// X/Y and Pick Location share one row, so the section stays two rows tall in both modes.
struct TargetSection: View {
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
        Section {
            Picker("Click at", selection: editor.kind) {
                Text("Current cursor").tag(ClickTargetEditor.Kind.currentCursor)
                Text("Fixed position").tag(ClickTargetEditor.Kind.fixed)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("targetKindPicker")

            if isFixed {
                LabeledContent {
                    HStack(spacing: 12) {
                        coordinateField("X", title: "X coordinate", value: editor.x, identifier: "targetX")
                        coordinateField("Y", title: "Y coordinate", value: editor.y, identifier: "targetY")
                    }
                } label: {
                    Text("Position")
                }
            }

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

            if isTargetInsideOwnWindow {
                WarningLabel("Move the cursor outside the AutoClicker window to start clicking.")
            }
        } header: {
            Text("Target")
        } footer: {
            // A footer rather than a subtitle, which would push X and Y onto a second line in the narrow column.
            if isFixed {
                // CG global points (ADR-006): what X and Y store, and what the user knows as screen coordinates.
                Text("X and Y are points from the top-left of the main display.")
            }
        }
        .onChange(of: target, initial: true) { _, newTarget in
            if case .fixed(let point) = newTarget {
                lastFixedPoint = point
            }
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

    private var isFixed: Bool {
        editor.wrappedValue.kind == .fixed
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
    Form {
        TargetSection(
            target: $target, pickLocationCountdown: nil, isTargetInsideOwnWindow: false,
            onPickLocation: {}, onCancelPickLocation: {})
    }
    .formStyle(.grouped)
    .frame(width: 540)
}

#Preview("Fixed, picking") {
    @Previewable @State var target = ClickTarget.fixed(CGPoint(x: 640, y: 400))
    Form {
        TargetSection(
            target: $target, pickLocationCountdown: 2, isTargetInsideOwnWindow: true,
            onPickLocation: {}, onCancelPickLocation: {})
    }
    .formStyle(.grouped)
    .frame(width: 540)
}
