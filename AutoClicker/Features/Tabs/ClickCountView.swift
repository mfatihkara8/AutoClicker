import SwiftUI

/// The Main tab's big click counter with its Reset button.
///
/// A view of its own so that only it reads `totalClicks`: the count changes on every UI sample while clicking, and
/// this keeps each update from re-evaluating the whole Main tab. The number also keeps a fixed height and no
/// shrink-to-fit, so a new value never re-measures or re-lays out the rest of the window (SC-6).
struct ClickCountView: View {
    let viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 2) {
            Text(viewModel.totalClicks, format: .number)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .accessibilityLabel("Total clicks")
                .accessibilityValue(Text(viewModel.totalClicks, format: .number))
                .accessibilityIdentifier("totalClicks")
            HStack(spacing: 8) {
                Text("Total clicks")
                    .foregroundStyle(.secondary)
                Button("Reset", systemImage: "arrow.counterclockwise", action: viewModel.resetCounter)
                    .buttonStyle(.borderless)
                    .help("Set the total click counter back to zero")
                    .accessibilityIdentifier("resetCounterButton")
            }
            .font(.callout)
        }
    }
}
