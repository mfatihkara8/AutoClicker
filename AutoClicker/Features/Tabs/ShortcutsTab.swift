import SwiftUI

/// The Shortcuts tab: the configurable start/stop shortcut and the fixed Esc emergency stop (SPEC §3.5).
///
/// Placeholder so the window shell (T-901) and this tab (T-903) can be built in parallel; T-903 replaces the body.
struct ShortcutsTab: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        Text("Shortcuts")
    }
}
