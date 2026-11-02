#if DIAGNOSTICS
    import AppKit

    /// Finds the SwiftUI main window once it is on screen.
    @MainActor
    enum MainWindowLocator {
        /// Waits up to `timeout` for the main window to be visible, checking ten times a second.
        static func waitForMainWindow(timeout: Duration = .seconds(15)) async -> NSWindow? {
            let deadline = ContinuousClock.now + timeout
            while ContinuousClock.now < deadline {
                if let window = mainWindow() {
                    return window
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            return nil
        }

        /// The `Window` scene's window: its identifier starts with the scene id "main". Falls back to any visible
        /// window that can become main, which leaves out the menu bar extra and other panels.
        static func mainWindow() -> NSWindow? {
            let candidates = NSApplication.shared.windows.filter { $0.isVisible && !($0 is NSPanel) }
            return candidates.first { $0.identifier?.rawValue.hasPrefix("main") == true }
                ?? candidates.first { $0.canBecomeMain && $0.sheetParent == nil }
        }
    }
#endif
