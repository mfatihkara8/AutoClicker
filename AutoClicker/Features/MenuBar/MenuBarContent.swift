import AppKit
import SwiftUI

/// The items of the menu bar extra: status, Start/Stop, Reset Counter, the Profiles submenu, Show Window and Quit.
///
/// Rendered with `.menuBarExtraStyle(.menu)`, so SwiftUI turns these views into native menu items and rebuilds them
/// each time the menu opens; the click count is therefore current whenever the user looks at it.
struct MenuBarContent: View {
    let viewModel: MainViewModel
    /// The id of the main `Window` scene, which `openWindow` brings to the front instead of duplicating.
    let mainWindowID: String

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let presentation = MenuBarPresentation(
            isRunning: viewModel.isRunning,
            totalClicks: viewModel.totalClicks,
            lastStopReason: viewModel.lastStopReason,
            toggleHotkeyName: viewModel.advertisedToggleHotkeyName,
            // Settings are locked while running, so the editable configuration is the one the run started with.
            clickType: viewModel.configuration.clickType,
            modifiers: viewModel.configuration.modifiers
        )

        // A plain `Text` becomes a disabled, informational menu item.
        Text(presentation.statusText)

        Divider()

        if viewModel.isRunning {
            Button(presentation.startStopTitle, action: viewModel.stop)
        } else {
            // Not disabled without permission: the cached trust can be stale while the window is closed, so the action
            // re-checks it and opens System Settings only if it is really missing.
            Button(presentation.startStopTitle, action: viewModel.startOrOpenAccessibilitySettings)
        }

        if !viewModel.isAccessibilityTrusted {
            Button("Grant Accessibility Permission…", action: viewModel.openAccessibilitySettings)
        }

        Button("Reset Counter", action: viewModel.resetCounter)

        if !viewModel.profiles.isEmpty {
            Divider()

            Menu("Profiles") {
                ForEach(viewModel.profiles) { profile in
                    // A toggle, so the menu draws the native checkmark on the active profile.
                    Toggle(isOn: isActiveBinding(for: profile.id)) {
                        Text(verbatim: profile.name)
                    }
                }
            }
            // Not while clicking, so a run keeps its configuration (SPEC §7.3).
            .disabled(!viewModel.canApplyProfile)
        }

        Divider()

        Button("Show AutoClicker Window", action: showMainWindow)
            .keyboardShortcut("0")

        Divider()

        Button("Quit AutoClicker") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// Checked for the active profile. Choosing any profile applies it, the active one too, which reverts changes made
    /// since it was applied.
    private func isActiveBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { viewModel.activeProfileID == id },
            set: { _ in viewModel.applyProfile(id: id) }
        )
    }

    private func showMainWindow() {
        openWindow(id: mainWindowID)
        // The app is not frontmost while its menu bar extra is used, so without this the window would open behind the
        // active app.
        NSApplication.shared.activate()
    }
}
