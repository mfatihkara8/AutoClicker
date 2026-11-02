import SwiftUI

/// The Edit Points sheet: one row per sequence point with X, Y and the delay before its click, plus Add Point, which
/// captures the cursor after the Pick Location countdown (SPEC §7.2).
///
/// Every edit goes through `ClickSequenceEditor`, which clamps it. While a run is active the points are locked, but Done
/// stays available.
struct SequenceEditorSheet: View {
    @Binding var points: [ClickPoint]
    let picking: SequencePointPicking

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if points.isEmpty {
                    ContentUnavailableView {
                        Label("No Points Yet", systemImage: "scope")
                    } description: {
                        // A non-breaking hyphen, so the sheet's width never wraps the line inside "3-second".
                        Text("Add Point captures the cursor position after a 3\u{2011}second countdown.")
                    }
                } else {
                    pointList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(picking.isLocked)
            Divider()
            footer
        }
        .frame(width: 560, height: 420)
        // The Click tab disables itself while clicking, and the sheet inherits that. Done must still close it.
        .environment(\.isEnabled, true)
        .onDisappear {
            picking.onCancelAddPoint()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Sequence Points")
                .font(.headline)
            Text("Each point waits for its delay, then clicks. After the last point, the sequence starts over.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var pointList: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    ForEach(points.indices, id: \.self) { index in
                        row(at: index)
                            .id(index)
                    }
                } footer: {
                    Text("X and Y are points from the top-left of the main display. Delays are in milliseconds.")
                }
            }
            .formStyle(.grouped)
            .onChange(of: points.count) { oldCount, newCount in
                // Show a point that Add Point just appended, which may be below the visible rows.
                guard newCount > oldCount else { return }
                withAnimation {
                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                }
            }
        }
    }

    private func row(at index: Int) -> some View {
        let number = index + 1
        return LabeledContent {
            HStack(spacing: 12) {
                coordinateField(
                    "X", title: "Point \(number) X coordinate",
                    value: binding {
                        $0.x(at: index)
                    } set: {
                        $0.setX($1, at: index)
                    },
                    identifier: "sequencePoint\(number)X")
                coordinateField(
                    "Y", title: "Point \(number) Y coordinate",
                    value: binding {
                        $0.y(at: index)
                    } set: {
                        $0.setY($1, at: index)
                    },
                    identifier: "sequencePoint\(number)Y")
                NumberField(
                    title: "Point \(number) delay in milliseconds",
                    value: binding {
                        $0.delayMilliseconds(at: index)
                    } set: {
                        $0.setDelayMilliseconds($1, at: index)
                    },
                    range: ClickPoint.delayRange, unit: "ms", fieldWidth: 76, showsStepper: false,
                    identifier: "sequencePoint\(number)Delay")
                rowActions(at: index, number: number)
            }
        } label: {
            Text("Point \(number)")
                .monospacedDigit()
        }
    }

    private func rowActions(at index: Int, number: Int) -> some View {
        let state = ClickSequenceEditor(points: points)
        return HStack(spacing: 2) {
            Button("Move Point \(number) Up", systemImage: "chevron.up") {
                edit { $0.moveUp(at: index) }
            }
            .disabled(!state.canMoveUp(at: index))
            .help("Move Up")
            Button("Move Point \(number) Down", systemImage: "chevron.down") {
                edit { $0.moveDown(at: index) }
            }
            .disabled(!state.canMoveDown(at: index))
            .help("Move Down")
            Button("Remove Point \(number)", systemImage: "minus.circle") {
                edit { $0.remove(at: index) }
            }
            .help("Remove")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 12) {
            if let countdown = picking.countdown {
                Label {
                    Text("Adding in \(countdown)…")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "hourglass")
                }
                .accessibilityIdentifier("addPointCountdown")
                Text("Move the cursor to the point.")
                    .foregroundStyle(.secondary)
                Button("Cancel", action: picking.onCancelAddPoint)
                    .accessibilityIdentifier("cancelAddPointButton")
            } else {
                Button("Add Point", systemImage: "plus", action: picking.onAddPoint)
                    .disabled(!picking.canAddPoint)
                    .help("Captures the cursor position as a new point after a 3-second countdown")
                    .accessibilityIdentifier("addPointButton")
                Text(addPointNote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // No Return shortcut: Return commits a number field, and must not close the sheet at the same time.
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("sequenceDoneButton")
        }
        .font(.callout)
        .padding()
    }

    private var addPointNote: LocalizedStringKey {
        if picking.isLocked {
            "Points are locked while clicking."
        } else if !ClickSequenceEditor(points: points).canAddPoint {
            "A sequence holds up to \(ClickTarget.maxSequencePoints) points."
        } else {
            "Captures the cursor in \(MainViewModel.pickLocationCountdownStart) s."
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
                showsStepper: false, identifier: identifier)
        }
    }

    /// A binding to one value of one point, read and written through the clamping editor.
    private func binding(
        get: @escaping (ClickSequenceEditor) -> Int, set: @escaping (inout ClickSequenceEditor, Int) -> Void
    ) -> Binding<Int> {
        Binding(
            get: { get(ClickSequenceEditor(points: points)) },
            set: { value in edit { set(&$0, value) } }
        )
    }

    private func edit(_ change: (inout ClickSequenceEditor) -> Void) {
        var editor = ClickSequenceEditor(points: points)
        change(&editor)
        points = editor.points
    }
}

#Preview("Points") {
    @Previewable @State var points = [
        ClickPoint(point: CGPoint(x: 100, y: 200), delayMilliseconds: 100),
        ClickPoint(point: CGPoint(x: 1640, y: -400), delayMilliseconds: 2_500),
        ClickPoint(point: CGPoint(x: 300, y: 400), delayMilliseconds: 50),
    ]
    SequenceEditorSheet(points: $points, picking: .preview)
}

#Preview("Empty, picking") {
    @Previewable @State var points: [ClickPoint] = []
    SequenceEditorSheet(
        points: $points,
        picking: SequencePointPicking(
            countdown: 2, canAddPoint: false, isLocked: false, onAddPoint: {}, onCancelAddPoint: {}))
}
