import AppKit
import SwiftUI

/// The main window with the Main, Click, Shortcuts and About tabs (SPEC §3.5).
///
/// The tabs are a native `TabView` at the top of the window, which macOS 26 and later draw as the Liquid Glass tab
/// bar. On macOS 15 and later a toolbar button moves them into a sidebar and back. Every tab gets the same chrome: the
/// Accessibility permission banner on top while permission is missing, and at the trailing end of the toolbar the run
/// status and a round Start/Stop button.
struct MainView: View {
    @Bindable var viewModel: MainViewModel
    @Bindable var navigation: WindowNavigation
    let appInfo: AppInfo
    let bugReportURL: URL?

    @Environment(\.scenePhase) private var scenePhase

    /// Whether the tabs are in a sidebar instead of the top tab bar. A view-only preference, so it is kept by the view
    /// rather than by `SettingsStore`.
    @AppStorage("showsTabsInSidebar") private var showsTabsInSidebar = false

    /// The sidebar's visibility in sidebar mode. Watched so that collapsing the sidebar, however it happens, moves the
    /// tabs back to the top instead of leaving the window without any.
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all

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
            Group {
                if showsTabsInSidebar {
                    sidebarLayout
                } else {
                    topTabBar
                }
            }
            // The window's name only repeats the app's name, and in the toolbar it is a hoverable region that does
            // nothing.
            .toolbar(removing: .title)
        } else {
            TabView(selection: $navigation.selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    page(for: tab, isInSidebarLayout: false)
                        .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                        .tag(tab)
                }
            }
        }
    }

    @available(macOS 15, *)
    private var topTabBar: some View {
        TabView(selection: $navigation.selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    page(for: tab, isInSidebarLayout: false)
                }
            }
        }
        .tabViewStyle(.tabBarOnly)
    }

    /// The tabs as a sidebar list.
    ///
    /// A `NavigationSplitView` rather than `TabView` with `.sidebarAdaptable`: on macOS that style does not adapt, and
    /// it offers no way to know that its sidebar collapsed, which leaves a window with no visible tabs at all.
    @available(macOS 15, *)
    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            List(AppTab.allCases, id: \.self, selection: sidebarSelection) { tab in
                Label(tab.title, systemImage: tab.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            // In the sidebar's part of the toolbar, so the button stays at the leading edge next to the window's
            // buttons, where it is in the top tab bar layout.
            .toolbar { sidebarModeItem }
            // The sidebar button is the only way in and out of the sidebar; the system's toggle would only collapse
            // it. Removed here on the sidebar column, because on the split view itself it has no effect.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            page(for: navigation.selectedTab, isInSidebarLayout: true)
                // Every tab is laid out for the default content size (SPEC §3.5), so the sidebar widens the window
                // instead of squeezing the tab. The explicit minimum also matters for the height: without it, the split
                // view sizes the detail for its narrowest width, where the wrapping permission banner makes it taller
                // than the window and pushes the content off screen.
                .frame(
                    minWidth: WindowMetrics.defaultContentSize.width, maxWidth: .infinity,
                    minHeight: WindowMetrics.defaultContentSize.height, maxHeight: .infinity
                )
                .navigationSplitViewColumnWidth(
                    min: WindowMetrics.defaultContentSize.width, ideal: WindowMetrics.defaultContentSize.width)
        }
        .onAppear { sidebarVisibility = .all }
        .onChange(of: sidebarVisibility) { _, visibility in
            if visibility == .detailOnly {
                showsTabsInSidebar = false
            }
        }
    }

    /// The sidebar list's selection. A list selection is optional, but the window always shows a tab, so clearing it
    /// keeps the current one.
    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { navigation.selectedTab },
            set: { tab in
                if let tab {
                    navigation.selectedTab = tab
                }
            }
        )
    }

    /// One tab's content with the chrome every tab shares.
    private func page(for tab: AppTab, isInSidebarLayout: Bool) -> some View {
        // Per tab rather than on the `TabView`, so the items are in the toolbar of whichever tab is shown.
        withToolbar(
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
            },
            isInSidebarLayout: isInSidebarLayout
        )
    }

    /// Adds the toolbar items, branching on the OS here because toolbar builders only support `#available` from
    /// macOS 14.5.
    ///
    /// In the top tab bar layout the sidebar button is part of the page's toolbar. In the sidebar layout it is in the
    /// sidebar column's toolbar instead, and the page's items need a spacer to stay at the trailing end, because
    /// nothing else in the detail column's toolbar pushes them there.
    @ViewBuilder private func withToolbar(_ content: some View, isInSidebarLayout: Bool) -> some View {
        if #available(macOS 26, *) {
            content.toolbar {
                if isInSidebarLayout {
                    ToolbarSpacer(.flexible)
                } else {
                    sidebarModeItem
                }
                // Without this, macOS 26 puts the indicator in a glass capsule that looks like a button.
                runStatusItem.sharedBackgroundVisibility(.hidden)
                startStopItem
            }
        } else if #available(macOS 15, *) {
            content.toolbar {
                if !isInSidebarLayout {
                    sidebarModeItem
                }
                runStatusItem
                startStopItem
            }
        } else {
            // macOS 14 has no sidebar mode, so the tabs stay at the top and there is nothing to switch.
            content.toolbar {
                runStatusItem
                startStopItem
            }
        }
    }

    /// Moves the tabs between the top tab bar and the sidebar.
    @available(macOS 15, *)
    private var sidebarModeItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                showsTabsInSidebar.toggle()
            } label: {
                Label(showsTabsInSidebar ? "Show Tabs at Top" : "Show Tabs in Sidebar", systemImage: "sidebar.left")
            }
            .help(showsTabsInSidebar ? "Show the tabs at the top" : "Show the tabs in a sidebar")
            .accessibilityIdentifier("sidebarModeButton")
        }
    }

    private var runStatusItem: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            RunStatusIndicator(isRunning: viewModel.isRunning)
        }
    }

    private var startStopItem: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
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
