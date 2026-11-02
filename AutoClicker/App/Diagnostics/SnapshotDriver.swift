#if DIAGNOSTICS
    import AppKit
    import SwiftUI

    /// Drives the main window through the states worth checking by eye, writes one PNG per state and
    /// `layout-report.txt`, then quits (`AUTOCLICKER_SNAPSHOTS=<dir>`).
    ///
    /// State is seeded only through the view model's and the navigation's own API, the fake permission checker, and
    /// the diagnostics `UserDefaults` suite that backs the view-only `@AppStorage` preferences. Sheets are hosted in
    /// their own window and presented as real sheets on the main window, because their presentation state is private
    /// to the views that own them.
    @MainActor
    final class SnapshotDriver {
        private let viewModel: MainViewModel
        private let navigation: WindowNavigation
        private let defaults: UserDefaults
        private let permissionChecker: DiagnosticsPermissionChecker
        private let snapshotter: WindowSnapshotter
        private let directory: URL
        private var report = LayoutReport()
        private var snapshotCount = 0

        /// How long a state change gets to lay out and draw before it is captured.
        private let settleTime: Duration = .milliseconds(700)

        /// MainView's `@AppStorage` key for the sidebar layout.
        private let sidebarKey = "showsTabsInSidebar"

        init(
            viewModel: MainViewModel,
            navigation: WindowNavigation,
            defaults: UserDefaults,
            permissionChecker: DiagnosticsPermissionChecker,
            directory: URL
        ) {
            self.viewModel = viewModel
            self.navigation = navigation
            self.defaults = defaults
            self.permissionChecker = permissionChecker
            self.directory = directory
            self.snapshotter = WindowSnapshotter(directory: directory)
        }

        func run() async {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                DiagnosticsLog.write("cannot create \(directory.path): \(error)")
                exit(EXIT_FAILURE)
            }
            guard let window = await MainWindowLocator.waitForMainWindow() else {
                report.note("FAILED: the main window never appeared.")
                finish(success: false)
                return
            }
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
            // Startup animations and the first permission read.
            try? await Task.sleep(for: .seconds(1.5))
            let initialFrame = window.frame
            report.note("Initial window frame: \(initialFrame), screen: \(window.screen?.frame ?? .zero)")

            await captureTabs(in: window, suffix: "top", note: "default settings, top tab bar")
            if #available(macOS 15, *) {
                await setSidebarLayout(true, window: window)
                await captureTabs(in: window, suffix: "sidebar", note: "default settings, sidebar layout")
                await setSidebarLayout(false, window: window, restoring: initialFrame)
            } else {
                report.note("Sidebar states skipped: the sidebar layout needs macOS 15.")
            }

            await captureTargets(in: window)
            await captureWorstClickTab(in: window, initialFrame: initialFrame)
            await captureOwnWindowRun(in: window)
            await captureProfiles(in: window)
            finish(success: true)
        }

        // MARK: - Scenarios

        private func captureTabs(in window: NSWindow, suffix: String, note: String) async {
            for tab in AppTab.allCases {
                navigation.selectedTab = tab
                await capture(window, "\(Self.slug(for: tab))-\(suffix)", note: note)
            }
        }

        private func captureTargets(in window: NSWindow) async {
            navigation.selectedTab = .click
            viewModel.configuration.target = .currentCursor
            await capture(window, "click-cursor-top", note: "target Current cursor")

            viewModel.configuration.target = .fixed(CGPoint(x: 640, y: 400))
            await capture(window, "click-fixed-top", note: "target Fixed (640, 400)")

            viewModel.configuration.target = .sequence(Self.points(count: 3))
            viewModel.configuration.positionOffset = 15
            await capture(window, "click-sequence-top", note: "target Sequence, 3 points, offset 15")

            viewModel.configuration.target = .sequence([])
            await capture(window, "click-empty-sequence-top", note: "target Sequence without points")
            navigation.selectedTab = .main
            await capture(window, "main-empty-sequence-top", note: "Main tab with an empty sequence (warning)")
        }

        private func captureWorstClickTab(in window: NSWindow, initialFrame: NSRect) async {
            viewModel.configuration.target = .fixed(CGPoint(x: 1234, y: 987))
            viewModel.configuration.positionOffset = 20
            viewModel.configuration.stopCondition = .afterDuration(.seconds(5_400))
            viewModel.configuration.interval = ClickInterval(
                hours: 1, minutes: 2, seconds: 3, milliseconds: 456, jitterMilliseconds: 50)
            viewModel.configuration.modifiers = [.shift, .command]
            viewModel.configuration.clickType = .double
            await setTrusted(false)
            navigation.selectedTab = .click
            await capture(
                window, "click-worst-top",
                note: "Fixed, offset 20, stop after 1:30:00, interval with jitter, ⇧⌘ double, permission banner")
            if #available(macOS 15, *) {
                await setSidebarLayout(true, window: window)
                await capture(window, "click-worst-sidebar", note: "the same, sidebar layout")
                await setSidebarLayout(false, window: window, restoring: initialFrame)
            }
            navigation.selectedTab = .main
            await capture(window, "main-banner-top", note: "Main tab with the permission banner")
            await setTrusted(true)
            viewModel.configuration = .default
        }

        /// Starts a real run (posting nothing) at a fixed target inside the main window, so the engine reports the
        /// own-window skip and both warnings appear. Ends with `.user` as the last stop reason.
        private func captureOwnWindowRun(in window: NSWindow) async {
            let windowFrame = ScreenGeometry.current().cgRect(fromAppKit: window.frame)
            viewModel.configuration.target = .fixed(CGPoint(x: windowFrame.midX, y: windowFrame.midY))
            navigation.selectedTab = .main
            try? await Task.sleep(for: settleTime)
            viewModel.start()
            guard viewModel.isRunning else {
                report.note("Own-window run skipped: start() did not start a run.")
                return
            }
            try? await Task.sleep(for: .seconds(1))
            await capture(window, "main-own-window-running-top", note: "running, target inside the window")
            navigation.selectedTab = .click
            await capture(
                window, "click-own-window-running-top", note: "running (tab disabled), target inside the window")
            viewModel.stop()
            await waitUntilStopped()
            viewModel.configuration = .default
        }

        private func captureProfiles(in window: NSWindow) async {
            navigation.selectedTab = .profiles
            await capture(window, "profiles-empty-top", note: "no profiles")

            saveProfile("Work", interval: 100, target: .currentCursor)
            saveProfile("Gaming", interval: 25, target: .fixed(CGPoint(x: 800, y: 450)))
            saveProfile(
                "A profile with a forty character name...", interval: 1_000, target: .sequence(Self.points(count: 3)))
            if let work = viewModel.profiles.first {
                viewModel.applyProfile(id: work.id)
            }
            viewModel.configuration.interval = ClickInterval(milliseconds: 250)
            await capture(window, "profiles-3-top", note: "3 profiles, Work active and modified")

            viewModel.configuration.target = .sequence([])
            navigation.selectedTab = .main
            await capture(
                window, "main-everything-top",
                note: "profile line (modified) + last stop reason + empty-sequence warning")
            await setTrusted(false)
            await capture(window, "main-everything-banner-top", note: "the same with the permission banner")
            await setTrusted(true)

            await captureSheets(in: window)

            viewModel.configuration.target = .currentCursor
            for index in 4...12 {
                saveProfile(
                    "Profile \(index)", interval: index * 10,
                    target: index.isMultiple(of: 2) ? .fixed(CGPoint(x: index * 50, y: index * 30)) : .currentCursor)
            }
            navigation.selectedTab = .profiles
            await capture(window, "profiles-12-top", note: "12 profiles, the last one active")
        }

        private func captureSheets(in window: NSWindow) async {
            navigation.selectedTab = .click
            viewModel.configuration.target = .sequence([])
            await captureSheet(on: window, "sheet-points-0", note: "Edit Points, no points") {
                SequenceEditorSheet(points: self.sequencePoints, picking: self.sequencePicking)
            }
            viewModel.configuration.target = .sequence(Self.points(count: 5))
            await captureSheet(on: window, "sheet-points-5", note: "Edit Points, 5 points") {
                SequenceEditorSheet(points: self.sequencePoints, picking: self.sequencePicking)
            }
            navigation.selectedTab = .profiles
            await captureSheet(on: window, "sheet-profile-name-duplicate", note: "Save as New Profile, name taken") {
                ProfileNameSheet(
                    title: "Save as New Profile",
                    confirmTitle: "Save",
                    initialName: "work",
                    rejection: { self.viewModel.profileNameRejection(for: $0) },
                    onConfirm: { self.viewModel.profileNameRejection(for: $0) }
                )
            }
        }

        // MARK: - Steps

        private func capture(_ window: NSWindow, _ name: String, note: String) async {
            try? await Task.sleep(for: settleTime)
            snapshotCount += 1
            let fileName = String(format: "%02d-%@", snapshotCount, name)
            do {
                try snapshotter.capture(window, name: fileName)
                report.record(name: fileName, note: note, window: window)
                DiagnosticsLog.write("wrote \(fileName).png")
            } catch {
                report.note("\(fileName): FAILED to capture: \(error)")
                DiagnosticsLog.write("failed to capture \(fileName): \(error)")
            }
        }

        /// Presents `content` as a real sheet on the main window, captures the sheet's window, then closes it.
        private func captureSheet(
            on window: NSWindow, _ name: String, note: String, @ViewBuilder content: () -> some View
        ) async {
            let controller = NSHostingController(rootView: content())
            controller.sizingOptions = .preferredContentSize
            let sheet = NSWindow(contentViewController: controller)
            window.beginSheet(sheet, completionHandler: nil)
            await capture(sheet, name, note: note)
            window.endSheet(sheet)
            sheet.orderOut(nil)
            try? await Task.sleep(for: .milliseconds(400))
        }

        @available(macOS 15, *)
        private func setSidebarLayout(_ isOn: Bool, window: NSWindow, restoring frame: NSRect? = nil) async {
            // The same `@AppStorage` value the toolbar button toggles.
            defaults.set(isOn, forKey: sidebarKey)
            try? await Task.sleep(for: settleTime)
            report.note(
                "Sidebar layout \(isOn ? "on" : "off"): window frame \(window.frame), content min \(window.contentMinSize)"
            )
            // The sidebar widens the window, and leaving it does not shrink the window back, so the top layout states
            // that follow are restored to the size they were captured at before.
            if let frame {
                window.setFrame(frame, display: true)
                try? await Task.sleep(for: settleTime)
                report.note("Window restored: frame \(window.frame), content min \(window.contentMinSize)")
            }
        }

        private func setTrusted(_ isTrusted: Bool) async {
            permissionChecker.setTrusted(isTrusted)
            // Monitoring is already on while the window is visible; this re-reads trust right away.
            viewModel.startPermissionMonitoring()
            try? await Task.sleep(for: .milliseconds(100))
        }

        private func saveProfile(_ name: String, interval milliseconds: Int, target: ClickTarget) {
            viewModel.configuration.interval = ClickInterval(milliseconds: milliseconds)
            viewModel.configuration.target = target
            if let rejection = viewModel.saveNewProfile(named: name) {
                report.note("Saving profile \(name) failed: \(rejection)")
            }
        }

        private func waitUntilStopped() async {
            for _ in 0..<50 where viewModel.isRunning {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        private func finish(success: Bool) {
            do {
                try report.write(to: directory.appendingPathComponent("layout-report.txt"))
            } catch {
                DiagnosticsLog.write("cannot write the layout report: \(error)")
            }
            DiagnosticsLog.write("done: \(snapshotCount) snapshots in \(directory.path)")
            if success {
                NSApplication.shared.terminate(nil)
            } else {
                exit(EXIT_FAILURE)
            }
        }

        // MARK: - Sheet inputs

        private var sequencePoints: Binding<[ClickPoint]> {
            Binding(
                get: {
                    guard case .sequence(let points) = self.viewModel.configuration.target else { return [] }
                    return points
                },
                set: { self.viewModel.configuration.target = .sequence($0) }
            )
        }

        private var sequencePicking: SequencePointPicking {
            SequencePointPicking(
                countdown: viewModel.addSequencePointCountdown,
                canAddPoint: viewModel.canAddSequencePoint,
                isLocked: viewModel.isRunning,
                onAddPoint: {},
                onCancelAddPoint: {})
        }

        // MARK: - Helpers

        private static func points(count: Int) -> [ClickPoint] {
            (0..<count).map { index in
                ClickPoint(
                    point: CGPoint(x: 200 + index * 180, y: 300 + index * 70),
                    delayMilliseconds: [100, 250, 1_500, 50, 86_400_000][index % 5])
            }
        }

        private static func slug(for tab: AppTab) -> String {
            switch tab {
            case .main: "main"
            case .click: "click"
            case .profiles: "profiles"
            case .shortcuts: "shortcuts"
            case .about: "about"
            }
        }
    }
#endif
