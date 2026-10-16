import AppKit

/// Keeps the app alive when its main window closes.
///
/// SwiftUI quits an app whose primary scene is a single `Window` as soon as that window closes, even when a
/// `MenuBarExtra` is present. AutoClicker must keep running, and keep clicking, from the menu bar, so it opts out here.
/// Quitting stays explicit: ⌘Q or the menu bar's Quit item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
