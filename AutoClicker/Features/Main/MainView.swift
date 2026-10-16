import SwiftUI

/// Minimal main window: status, counter, Start/Stop and Pick Location. Replaced by the card-based UI in M5 (T-502).
struct MainView: View {
    let viewModel: MainViewModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PermissionBanner(
                isTrusted: viewModel.isAccessibilityTrusted,
                onOpenSettings: viewModel.openAccessibilitySettings,
                onRequestAccess: viewModel.requestAccessibilityPermission
            )

            HStack {
                Label(
                    viewModel.isRunning ? "Active" : "Inactive",
                    systemImage: viewModel.isRunning ? "circle.fill" : "circle"
                )
                .foregroundStyle(viewModel.isRunning ? .green : .secondary)
                .accessibilityIdentifier("statusLabel")

                Spacer()

                Text("Total clicks: \(viewModel.totalClicks)")
                    .monospacedDigit()
                    .accessibilityIdentifier("totalClicks")
                Button("Reset", action: viewModel.resetCounter)
            }

            HStack {
                if viewModel.isRunning {
                    Button("Stop", action: viewModel.stop)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Start", action: viewModel.start)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!viewModel.canStart)
                }

                Spacer()

                if let countdown = viewModel.pickLocationCountdown {
                    Text("Picking in \(countdown)…")
                        .monospacedDigit()
                    Button("Cancel", action: viewModel.cancelPickLocation)
                } else {
                    Button("Pick Location", action: viewModel.pickLocation)
                        .disabled(viewModel.isRunning)
                }
            }

            Text("Target: \(targetDescription)")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let reason = viewModel.lastStopReason, !viewModel.isRunning {
                Text(reason.displayText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("lastStopReason")
            }

            if viewModel.isTargetInsideOwnWindow {
                warning(Text("Move the cursor outside the AutoClicker window to start clicking."))
            }
            if let hotkeyWarning = viewModel.hotkeyWarning {
                // Already localized by the view model, so shown verbatim.
                warning(Text(hotkeyWarning))
            }
            if let emergencyStopWarning = viewModel.emergencyStopWarning, viewModel.isRunning {
                warning(Text(emergencyStopWarning))
            }

            Text("F6 starts and stops. Esc stops while clicking.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 420)
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

    private var targetDescription: String {
        switch viewModel.configuration.target {
        case .currentCursor:
            String(localized: "current cursor position", comment: "Target description for the cursor target.")
        case .fixed(let point):
            String(
                localized: "x \(Int(point.x.rounded())), y \(Int(point.y.rounded()))",
                comment: "Target description for a fixed point; the arguments are CG global coordinates.")
        }
    }

    private func warning(_ text: Text) -> some View {
        Label {
            text
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.callout)
        .foregroundStyle(.orange)
    }
}
