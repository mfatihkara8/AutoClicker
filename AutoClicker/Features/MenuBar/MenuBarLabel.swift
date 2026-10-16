import SwiftUI

/// The icon shown in the system menu bar. It changes symbol while clicking, so the state is visible without opening
/// the menu.
struct MenuBarLabel: View {
    let viewModel: MainViewModel

    var body: some View {
        // Reads only `isRunning`, so the icon is not re-rendered on every counter sample.
        let isRunning = viewModel.isRunning
        Image(systemName: MenuBarPresentation.symbolName(isRunning: isRunning))
            .accessibilityLabel(Text(MenuBarPresentation.accessibilityLabel(isRunning: isRunning)))
    }
}
