import SwiftUI

/// Placeholder main window. Replaced by the card-based UI in M5 (T-502).
struct MainView: View {
    let permissionManager: PermissionManager

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 16) {
            PermissionBanner(
                isTrusted: permissionManager.isTrusted,
                onOpenSettings: permissionManager.openAccessibilitySettings,
                onRequestAccess: permissionManager.requestPermission
            )

            Image(systemName: "cursorarrow.click.2")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("AutoClicker")
        }
        .padding()
        .frame(minWidth: 420)
        .animation(.default, value: permissionManager.isTrusted)
        // Poll only while the window is on screen (SPEC section 2).
        .onAppear { permissionManager.startMonitoring() }
        .onDisappear { permissionManager.stopMonitoring() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                permissionManager.stopMonitoring()
            } else {
                permissionManager.startMonitoring()
            }
        }
    }
}
