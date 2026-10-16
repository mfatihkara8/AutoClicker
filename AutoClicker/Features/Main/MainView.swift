import SwiftUI

/// The main window: the permission banner and the run status on top, the settings cards and hotkey hint below.
///
/// The status stays pinned so Start/Stop is always visible; the settings scroll when the window is short. All
/// settings are disabled while a run is active, so each run uses the configuration it was started with.
struct MainView: View {
    @Bindable var viewModel: MainViewModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                PermissionBanner(
                    isTrusted: viewModel.isAccessibilityTrusted,
                    onOpenSettings: viewModel.openAccessibilitySettings,
                    onRequestAccess: viewModel.requestAccessibilityPermission
                )

                StatusCard(
                    isRunning: viewModel.isRunning,
                    canStart: viewModel.canStart,
                    totalClicks: viewModel.totalClicks,
                    lastStopReason: viewModel.isRunning ? nil : viewModel.lastStopReason?.displayText,
                    onStart: viewModel.start,
                    onStop: viewModel.stop,
                    onResetCounter: viewModel.resetCounter
                )
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    settingsCards
                        .disabled(viewModel.isRunning)

                    HotkeyHint(
                        hotkeyWarning: viewModel.hotkeyWarning,
                        emergencyStopWarning: viewModel.emergencyStopWarning
                    )
                    .padding(.horizontal, 4)
                }
                .padding()
            }
        }
        .frame(minWidth: 480, idealWidth: 500, minHeight: 560, idealHeight: 820)
        .animation(.default, value: viewModel.isAccessibilityTrusted)
        // Poll only while the window is on screen (SPEC section 2).
        .onAppear { viewModel.startPermissionMonitoring() }
        .onDisappear { viewModel.stopPermissionMonitoring() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                viewModel.stopPermissionMonitoring()
            } else {
                viewModel.startPermissionMonitoring()
            }
        }
    }

    private var settingsCards: some View {
        VStack(spacing: 12) {
            ClickTypeCard(clickType: $viewModel.configuration.clickType)
            IntervalCard(interval: $viewModel.configuration.interval)
            TargetCard(
                target: $viewModel.configuration.target,
                pickLocationCountdown: viewModel.pickLocationCountdown,
                isTargetInsideOwnWindow: viewModel.isTargetInsideOwnWindow,
                onPickLocation: viewModel.pickLocation,
                onCancelPickLocation: viewModel.cancelPickLocation
            )
            StopConditionCard(stopCondition: $viewModel.configuration.stopCondition)
        }
    }
}
