import AppKit
import SwiftUI

@main
struct AutoClickerApp: App {
    // Composition root: the concrete adapters are created here and injected.
    @State private var permissionManager = PermissionManager(
        checker: AccessibilityPermissionChecker(),
        openURL: { url in NSWorkspace.shared.open(url) }
    )

    var body: some Scene {
        WindowGroup {
            MainView(permissionManager: permissionManager)
        }
    }
}
