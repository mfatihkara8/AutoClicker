import AppKit
import SwiftUI

@main
struct AutoClickerApp: App {
    /// Owned by the app, not the window, so clicking continues while the window is closed.
    @State private var viewModel: MainViewModel

    /// Composition root: the concrete adapters are created here and injected. No singletons.
    init() {
        // The unit tests run hosted in this app. As a test host it must not register real hotkeys or touch the
        // user's saved settings.
        let isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

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
        WindowGroup {
            MainView(viewModel: viewModel)
        }
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
