import SwiftUI

/// The Click tab: click type and held modifiers, interval and jitter, target and stop condition (SPEC §3.5).
///
/// Two grouped forms side by side (Click and Interval on the left, Target and Stop on the right), because the four
/// sections do not fit `WindowMetrics.defaultContentSize` in one column and the tab must not scroll at that size. The
/// whole tab is disabled while clicking, so each run uses the configuration it was started with.
struct ClickTab: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                ClickTypeSection(
                    clickType: $viewModel.configuration.clickType, modifiers: $viewModel.configuration.modifiers)
                IntervalSection(interval: $viewModel.configuration.interval)
            }
            .formStyle(.grouped)
            .tabFormBackground()

            Form {
                TargetSection(
                    target: $viewModel.configuration.target,
                    pickLocationCountdown: viewModel.pickLocationCountdown,
                    isTargetInsideOwnWindow: viewModel.isTargetInsideOwnWindow,
                    onPickLocation: viewModel.pickLocation,
                    onCancelPickLocation: viewModel.cancelPickLocation
                )
                StopConditionSection(stopCondition: $viewModel.configuration.stopCondition)
            }
            .formStyle(.grouped)
            .tabFormBackground()
        }
        .disabled(viewModel.isRunning)
    }
}
