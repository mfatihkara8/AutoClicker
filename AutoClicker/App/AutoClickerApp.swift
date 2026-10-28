import AppKit
import SwiftUI

@main
struct AutoClickerApp: App {
    /// Owned by the app, not the window, so clicking continues while the window is closed.
    @State private var viewModel: MainViewModel

    /// The main window's selected tab. Owned here, next to the window, so the menu commands can select a tab too.
    @State private var navigation = WindowNavigation()

    /// The app's name and versions, read once from the bundle for About and bug reports.
    private let appInfo = AppInfo.current()

    /// Stops SwiftUI from quitting the app when the main window closes.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Whether the unit tests are running hosted in this app.
    private let isTestHost: Bool

    /// The id of the single main window, shared with the menu bar extra so it can bring the window back.
    private static let mainWindowID = "main"

    /// Composition root: the concrete adapters are created here and injected. No singletons.
    init() {
        // The unit tests run hosted in this app. As a test host it must not register real hotkeys or touch the
        // user's saved settings.
        let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        self.isTestHost = isTestHost

        let counter = ClickCounter()
        let failsafe = FailsafeMonitor(geometry: .current())
        let engine = ClickEngine(poster: CGEventPoster(), counter: counter, failsafe: failsafe)
        let permissionManager = PermissionManager(
            checker: AccessibilityPermissionChecker(),
            openURL: { url in NSWorkspace.shared.open(url) }
        )
        let viewModel = MainViewModel(
            engine: engine,
            counter: counter,
            failsafe: failsafe,
            hotkeys: CarbonHotkeyManager(),
            // Installs no monitor until the user clicks Change…, so it is safe in the test host too.
            shortcutRecorder: LocalShortcutRecorder(),
            permissionManager: permissionManager,
            settingsStore: SettingsStore(defaults: Self.makeDefaults(isTestHost: isTestHost))
        )
        if !isTestHost {
            viewModel.activate()
        }
        _viewModel = State(initialValue: viewModel)

        // Registered here rather than in a view, because the window may already be closed when the app quits. The
        // observer lives as long as the app, so its token is not kept.
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak viewModel] _ in
            MainActor.assumeIsolated {
                viewModel?.flushPendingSave()
            }
        }
    }

    var body: some Scene {
        // `Window`, not `WindowGroup`: this utility has exactly one main window, so `openWindow(id:)` from the menu bar
        // brings the existing window to the front instead of opening a second copy, and File > New does not exist. As
        // the first scene it still opens at launch.
        Window("AutoClicker", id: Self.mainWindowID) {
            MainView(viewModel: viewModel, navigation: navigation, appInfo: appInfo, bugReportURL: bugReportURL)
                // Every tab is laid out for this size, so the window may grow but never shrink below it (SPEC §3.5).
                .frame(
                    minWidth: WindowMetrics.defaultContentSize.width,
                    minHeight: WindowMetrics.defaultContentSize.height)
        }
        .defaultSize(WindowMetrics.defaultContentSize)
        .windowResizability(.contentMinSize)
        .keyboardShortcut("0")
        .commands {
            AppCommands(navigation: navigation, mainWindowID: Self.mainWindowID, bugReportURL: bugReportURL)
        }

        // Always present, so the app keeps running (and clicking) after the window is closed. Hidden when hosting the
        // unit tests, so a test run leaves no icon in the user's menu bar.
        MenuBarExtra(isInserted: .constant(!isTestHost)) {
            MenuBarContent(viewModel: viewModel, mainWindowID: Self.mainWindowID)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.menu)
    }

    /// The new-issue link prefilled with this app's and macOS's versions.
    private var bugReportURL: URL? {
        BugReportLink.url(for: appInfo)
    }

    /// The user's defaults, or a throwaway suite that is wiped on every launch when running as a test host.
    private static func makeDefaults(isTestHost: Bool) -> UserDefaults {
        let suiteName = "AutoClicker.TestHost"
        // `init(suiteName:)` only fails for the app's own bundle ID or the global domain, which this name is not.
        if isTestHost, let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }
        return .standard
    }
}
