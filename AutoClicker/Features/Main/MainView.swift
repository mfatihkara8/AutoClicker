import AppKit
import SwiftUI

/// The main window: a native `TabView` with the Main, Click, Shortcuts and About tabs (SPEC §3.5).
///
/// Every tab gets the same chrome: the Accessibility permission banner on top while permission is missing, and a
/// compact Start/Stop button at the trailing end of the toolbar. The tabs use the system's own look, so macOS 26 and
/// later show the Liquid Glass tab bar, and macOS 15 and later let the user switch to a sidebar.
struct MainView: View {
    @Bindable var viewModel: MainViewModel
    @Bindable var navigation: WindowNavigation
    let appInfo: AppInfo
    let bugReportURL: URL?

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        tabs
            .animation(.default, value: viewModel.isAccessibilityTrusted)
            // Poll only while the window is on screen (SPEC section 2).
            .onAppear { viewModel.startPermissionMonitoring() }
            .onDisappear {
                viewModel.stopPermissionMonitoring()
                // The recorder only sees this window's keys, so a session must not outlive it.
                viewModel.cancelRecordingShortcut()
                // The window always opens on Main; the last tab is not remembered (SPEC §3.5).
                navigation.reset()
            }
            // The recording prompt lives on the Shortcuts tab; leaving it mid-recording would otherwise leave the
            // shortcut unregistered with nothing on screen saying so.
            .onChange(of: navigation.selectedTab) {
                viewModel.cancelRecordingShortcut()
            }
            // No key reaches the recorder while another app is active, and recording keeps the shortcut unregistered,
            // so leaving the app mid-recording would otherwise leave the user without a working shortcut.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                viewModel.cancelRecordingShortcut()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    viewModel.stopPermissionMonitoring()
                } else {
                    viewModel.startPermissionMonitoring()
                }
            }
    }

    @ViewBuilder private var tabs: some View {
        if #available(macOS 15, *) {
            TabView(selection: $navigation.selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                        page(for: tab)
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        } else {
            TabView(selection: $navigation.selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    page(for: tab)
                        .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                        .tag(tab)
                }
            }
        }
    }

    /// One tab's content with the chrome every tab shares.
    private func page(for tab: AppTab) -> some View {
        VStack(spacing: 0) {
            if !viewModel.isAccessibilityTrusted {
                PermissionBanner(
                    isTrusted: viewModel.isAccessibilityTrusted,
                    onOpenSettings: viewModel.openAccessibilitySettings,
                    onRequestAccess: viewModel.requestAccessibilityPermission
                )
                .padding([.horizontal, .top])
            }
            content(for: tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Per tab rather than on the `TabView`, so the button is in the toolbar of whichever tab is shown, in the tab
        // bar and in the sidebar layout alike.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                StartStopButton(
                    size: .compact,
                    isRunning: viewModel.isRunning,
                    canStart: viewModel.canStart,
                    toggleHotkeyName: viewModel.advertisedToggleHotkeyName,
                    onStart: viewModel.start,
                    onStop: viewModel.stop
                )
                .accessibilityIdentifier("toolbarStartStopButton")
            }
        }
    }

    @ViewBuilder private func content(for tab: AppTab) -> some View {
        switch tab {
        case .main:
            MainTab(viewModel: viewModel)
        case .click:
            ClickTab(viewModel: viewModel)
        case .shortcuts:
            ShortcutsTab(viewModel: viewModel)
        case .about:
            AboutTab(viewModel: viewModel, appInfo: appInfo, bugReportURL: bugReportURL)
        }
    }
}
