import Observation

/// Which tab the main window shows.
///
/// Owned by the app rather than the window, because the menu commands (About AutoClicker, Settings…) select a tab
/// too, and they must work while the window is closed. It is never persisted: the window always opens on Main
/// (SPEC §3.5).
@Observable @MainActor
final class WindowNavigation {
    /// The tab currently shown, or shown as soon as the window opens.
    var selectedTab: AppTab = .main

    /// Goes back to Main. Called when the window closes, so the next time it opens it starts on Main again.
    func reset() {
        selectedTab = .main
    }
}
