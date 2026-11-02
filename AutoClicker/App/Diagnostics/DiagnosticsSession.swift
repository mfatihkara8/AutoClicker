#if DIAGNOSTICS
    import AppKit

    /// Everything a diagnostics launch swaps into the composition root, and the driver it runs after launch.
    ///
    /// Created only when `DiagnosticsMode.current(environment:)` finds one of its environment variables. Then:
    /// - settings live in a throwaway `UserDefaults` suite, also used for `@AppStorage`, so the user's real settings
    ///   are never read or written;
    /// - the event poster posts nothing, and Accessibility trust is faked, so a run starts without the real grant;
    /// - snapshot runs also register no real hotkeys and hide the menu bar extra.
    @MainActor
    final class DiagnosticsSession {
        let mode: DiagnosticsMode
        let defaults: UserDefaults
        let permissionChecker = DiagnosticsPermissionChecker(isTrusted: true)

        private let suite: DiagnosticsDefaults

        /// Returns a session when the environment asks for one, or `nil` for a normal launch.
        static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment)
            -> DiagnosticsSession?
        {
            guard let mode = DiagnosticsMode.current(environment: environment) else { return nil }
            guard let suite = DiagnosticsDefaults() else {
                // Never fall back to the user's defaults.
                DiagnosticsLog.write("cannot create the throwaway defaults suite; quitting")
                exit(EXIT_FAILURE)
            }
            return DiagnosticsSession(mode: mode, suite: suite)
        }

        private init(mode: DiagnosticsMode, suite: DiagnosticsDefaults) {
            self.mode = mode
            self.suite = suite
            self.defaults = suite.defaults
            DiagnosticsLog.write("mode \(mode), settings in \(suite.suiteName)")
        }

        /// Posts nothing: a diagnostics run must never click.
        let eventPoster: any EventPosting = NoOpEventPoster()

        /// Real Carbon hotkeys for a dry run, so it costs what a real run costs; none for snapshots, so the installed
        /// app keeps F6 and no "shortcut in use" warning shows up in the pictures.
        func makeHotkeyProvider() -> any HotkeyProviding {
            switch mode {
            case .snapshots: NoOpHotkeyProvider()
            case .dryRun: CarbonHotkeyManager()
            }
        }

        /// Whether the menu bar extra is shown. A dry run keeps it, because its label updates during a run.
        var showsMenuBarExtra: Bool {
            if case .snapshots = mode { return false }
            return true
        }

        /// Starts the driver once the app has launched, and removes the defaults suite when the app quits.
        func start(viewModel: MainViewModel, navigation: WindowNavigation) {
            let suiteName = suite.suiteName
            // The observer lives as long as the app, so its token is not kept.
            _ = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { _ in
                DiagnosticsDefaults.remove(suiteName: suiteName)
            }
            switch mode {
            case .snapshots(let directory):
                let driver = SnapshotDriver(
                    viewModel: viewModel, navigation: navigation, defaults: defaults,
                    permissionChecker: permissionChecker, directory: directory)
                Task { await driver.run() }
            case .dryRun(let seconds, let delays):
                let driver = DryRunDriver(
                    viewModel: viewModel, navigation: navigation, seconds: seconds, delays: delays)
                Task { await driver.run() }
            }
        }
    }
#endif
