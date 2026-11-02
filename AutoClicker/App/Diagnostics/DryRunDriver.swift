#if DIAGNOSTICS
    import AppKit

    /// A run for measuring CPU without real clicks (`AUTOCLICKER_DRY_RUN=<seconds>`): idle on the Main tab for 5 s, run
    /// a sequence with a 20 pt offset for the given duration, idle for 10 s, then quit. The event poster is a no-op, so
    /// nothing is clicked.
    ///
    /// The sequence has one point per delay. The default 3, 3 and 4 ms make one 10 ms cycle, about 300 clicks a second;
    /// `AUTOCLICKER_DRY_RUN_DELAYS=10,10,10` matches SC-6's 10 ms interval instead.
    ///
    /// Pair it with `scripts/measure-performance.sh` on a `scripts/build-release.sh --profiling` build.
    @MainActor
    final class DryRunDriver {
        private let viewModel: MainViewModel
        private let navigation: WindowNavigation
        private let seconds: Int
        private let delays: [Int]

        /// The idle time before the run starts.
        private let idleBefore: Duration = .seconds(5)
        /// The idle time after the run ends, before quitting.
        private let idleAfter: Duration = .seconds(10)

        init(viewModel: MainViewModel, navigation: WindowNavigation, seconds: Int, delays: [Int]) {
            self.viewModel = viewModel
            self.navigation = navigation
            self.seconds = seconds
            self.delays = delays
        }

        func run() async {
            guard let window = await MainWindowLocator.waitForMainWindow() else {
                DiagnosticsLog.write("dry run: the main window never appeared")
                exit(EXIT_FAILURE)
            }
            let geometry = ScreenGeometry.current()
            let points = Self.points(
                delays: delays, avoiding: geometry.cgRect(fromAppKit: window.frame), geometry: geometry)
            viewModel.configuration = ClickConfiguration(
                clickType: .left,
                interval: ClickInterval(milliseconds: 10),
                target: .sequence(points),
                stopCondition: .afterDuration(.seconds(seconds)),
                positionOffset: 20)
            navigation.selectedTab = .main
            DiagnosticsLog.write(
                "dry run: idle \(idleBefore), then \(seconds) s of clicks at "
                    + points.map { "(\(Int($0.point.x)), \(Int($0.point.y))) after \($0.delayMilliseconds) ms" }
                    .joined(separator: ", "))

            try? await Task.sleep(for: idleBefore)
            viewModel.start()
            guard viewModel.isRunning else {
                DiagnosticsLog.write("dry run: start() did not start a run")
                exit(EXIT_FAILURE)
            }
            DiagnosticsLog.write("dry run: started at \(Date.now)")
            // One wake-up for the whole run, then a short poll for the stop callback, so the driver adds no CPU.
            try? await Task.sleep(for: .seconds(seconds))
            for _ in 0..<100 where viewModel.isRunning {
                try? await Task.sleep(for: .milliseconds(100))
            }
            let reason = viewModel.lastStopReason.map { "\($0)" } ?? "none (still running)"
            DiagnosticsLog.write(
                "dry run: ended at \(Date.now), \(viewModel.totalClicks) clicks counted, stop reason \(reason)")

            try? await Task.sleep(for: idleAfter)
            DiagnosticsLog.write("dry run: done, quitting")
            NSApplication.shared.terminate(nil)
        }

        /// One point per delay, 20 pt apart in a column near the left edge of the main display, moved to the right edge
        /// when the window covers it. They keep clear of the corners and of the window, offset included, so every tick
        /// is a counted click rather than a skip or a failsafe stop.
        private static func points(
            delays: [Int], avoiding windowFrame: CGRect, geometry: ScreenGeometry
        ) -> [ClickPoint] {
            let screen = geometry.cgScreenFrames.first ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            let margin: CGFloat = 80
            let left = CGPoint(x: screen.minX + margin, y: screen.midY)
            let right = CGPoint(x: screen.maxX - margin, y: screen.midY)
            let clearance = windowFrame.insetBy(dx: -80, dy: -80)
            let base = clearance.contains(left) ? right : left
            if clearance.contains(base) {
                DiagnosticsLog.write("dry run: warning, the window covers both screen edges; clicks may be skipped")
            }
            return delays.enumerated().map { index, delay in
                let dy = CGFloat(index - delays.count / 2) * 20
                return ClickPoint(point: CGPoint(x: base.x, y: base.y + dy), delayMilliseconds: delay)
            }
        }
    }
#endif
