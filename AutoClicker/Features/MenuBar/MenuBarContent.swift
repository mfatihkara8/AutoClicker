import AppKit
import SwiftUI

/// The items of the menu bar extra: status, Start/Stop, Reset Counter, Show Window and Quit.
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
            isHotkeyAvailable: viewModel.hotkeyWarning == nil
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

        Divider()

        Button("Show AutoClicker Window", action: showMainWindow)
            .keyboardShortcut("0")

        Divider()

        Button("Quit AutoClicker") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func showMainWindow() {
        openWindow(id: mainWindowID)
        // The app is not frontmost while its menu bar extra is used, so without this the window would open behind the
        // active app.
        NSApplication.shared.activate()
    }
}
