#if DIAGNOSTICS
    import AppKit

    /// Everything a diagnostics launch swaps into the composition root, and the driver it runs after launch.
    ///
    /// Created only when `DiagnosticsMode.current(environment:)` finds one of its environment variables. Then:
    /// - settings live in a throwaway `UserDefaults` suite, also used for `@AppStorage`, so the user's real settings
    ///   are never read or written;
    /// - for snapshots and dry runs, the event poster posts nothing, and Accessibility trust is faked, so a run starts
    ///   without the real grant;
    /// - snapshot runs also register no real hotkeys and hide the menu bar extra;
    /// - a showcase posts nothing, fakes trust and registers no hotkeys, but keeps the menu bar extra for screenshots;
    /// - a live check keeps the real event poster, the real trust check and real hotkeys (Esc stops its run), because
    ///   checking real events end to end is its whole point.
    @MainActor
    final class DiagnosticsSession {
        let mode: DiagnosticsMode
        let defaults: UserDefaults
        /// The trust state snapshots and dry runs fake. Never used for a live check.
        let fakePermissionChecker = DiagnosticsPermissionChecker(isTrusted: true)

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

        /// Posts nothing, so snapshots and dry runs never click; a live check posts real clicks.
        var eventPoster: any EventPosting {
            if case .liveCheck = mode { return CGEventPoster() }
            return NoOpEventPoster()
        }

        /// The real Accessibility check for a live check, which must not post on faked trust; fake trust otherwise,
        /// paired with the poster that posts nothing.
        var permissionChecker: any PermissionChecking {
            if case .liveCheck = mode { return AccessibilityPermissionChecker() }
            return fakePermissionChecker
        }

        /// Real Carbon hotkeys for a dry run, so it costs what a real run costs, and for a live check, so Esc stops its
        /// clicks; none for snapshots, so the installed app keeps F6 and no "shortcut in use" warning shows up in the
        /// pictures.
        func makeHotkeyProvider() -> any HotkeyProviding {
            switch mode {
            case .snapshots, .showcase: NoOpHotkeyProvider()
            case .dryRun, .liveCheck: CarbonHotkeyManager()
            }
        }

        /// Whether the menu bar extra is shown. A dry run keeps it, because its label updates during a run, and a live
        /// check uses its Profiles submenu.
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
                    permissionChecker: fakePermissionChecker, directory: directory)
                Task { await driver.run() }
            case .dryRun(let seconds, let delays):
                let driver = DryRunDriver(
                    viewModel: viewModel, navigation: navigation, seconds: seconds, delays: delays)
                Task { await driver.run() }
            case .liveCheck(let frameFile, let resultFile):
                let driver = LiveCheckDriver(
                    viewModel: viewModel, navigation: navigation, frameFile: frameFile, resultFile: resultFile)
                Task { await driver.run() }
            case .showcase:
                let driver = ShowcaseDriver(viewModel: viewModel, navigation: navigation)
                Task { await driver.run() }
            }
        }
    }
#endif
