import SwiftUI

/// The Click tab: click type and held modifiers, interval and jitter, target and stop condition (SPEC §3.5).
///
/// Placeholder so the window shell (T-901) and this tab (T-903) can be built in parallel; T-903 replaces the body.
struct ClickTab: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        Text("Click settings")
    }
}
