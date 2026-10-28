import AppKit
import SwiftUI

/// The app's menu commands: About AutoClicker and Settings… select a tab of the main window, and the Help menu offers
/// Report a Bug… (SPEC §3.5).
struct AppCommands: Commands {
    let navigation: WindowNavigation
    /// The id of the main `Window` scene, which `openWindow` brings to the front instead of duplicating.
    let mainWindowID: String
    let bugReportURL: URL?

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About AutoClicker") { show(.about) }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { show(.shortcuts) }
                .keyboardShortcut(",")
        }

        // Replaces the default "AutoClicker Help" item, which would only say that no help is available.
        CommandGroup(replacing: .help) {
            Button("Report a Bug…") {
                if let bugReportURL {
                    openURL(bugReportURL)
                }
            }
            .disabled(bugReportURL == nil)
        }
    }

    /// Selects `tab` and brings the main window forward, opening it first if it was closed.
    private func show(_ tab: AppTab) {
        navigation.selectedTab = tab
        openWindow(id: mainWindowID)
        // The app may not be frontmost, for example right after the menu bar extra was used.
        NSApplication.shared.activate()
    }
}
