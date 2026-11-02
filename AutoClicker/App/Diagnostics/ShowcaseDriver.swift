#if DIAGNOSTICS
    import AppKit

    /// Stages realistic sample data for README screenshots and then leaves the app open (`AUTOCLICKER_SHOWCASE=1`).
    ///
    /// It saves three profiles, runs a short click run on the no-op poster so the counter and the last stop reason are
    /// filled, applies the "Work" profile (a three-point sequence with an offset) and selects the Main tab. Everything
    /// lives in the throwaway settings suite, nothing is clicked and no hotkeys are registered, so the user's real
    /// settings, profiles and F6 stay untouched. The app keeps running until the user quits it.
    @MainActor
    final class ShowcaseDriver {
        private let viewModel: MainViewModel
        private let navigation: WindowNavigation

        /// The clicks of the staged run, shown by the Main tab's counter.
        private let stagedClicks = 1_250

        init(viewModel: MainViewModel, navigation: WindowNavigation) {
            self.viewModel = viewModel
            self.navigation = navigation
        }

        func run() async {
            guard let window = await MainWindowLocator.waitForMainWindow() else {
                DiagnosticsLog.write("showcase: the main window never appeared")
                exit(EXIT_FAILURE)
            }

            let work = ClickConfiguration(
                clickType: .left,
                interval: ClickInterval(milliseconds: 250),
                target: .sequence([
                    ClickPoint(point: CGPoint(x: 420, y: 310), delayMilliseconds: 250),
                    ClickPoint(point: CGPoint(x: 860, y: 310), delayMilliseconds: 250),
                    ClickPoint(point: CGPoint(x: 640, y: 560), delayMilliseconds: 500),
                ]),
                stopCondition: .never,
                positionOffset: 10)
            let gaming = ClickConfiguration(
                clickType: .double,
                interval: ClickInterval(milliseconds: 25, jitterMilliseconds: 5),
                target: .currentCursor,
                stopCondition: .afterDuration(.seconds(60)))
            let formFiller = ClickConfiguration(
                clickType: .left,
                interval: ClickInterval(seconds: 1),
                target: .fixed(CGPoint(x: 960, y: 540)),
                stopCondition: .afterClicks(100),
                modifiers: .command)

            for (name, configuration) in [("Work", work), ("Gaming", gaming), ("Form Filler", formFiller)] {
                viewModel.configuration = configuration
                if let rejection = viewModel.saveNewProfile(named: name) {
                    DiagnosticsLog.write("showcase: could not save \(name): \(rejection)")
                }
            }

            await stageRun(avoiding: window)

            if let workID = viewModel.profiles.first(where: { $0.name == "Work" })?.id,
                !viewModel.applyProfile(id: workID)
            {
                DiagnosticsLog.write("showcase: could not apply Work")
            }
            navigation.selectedTab = .main
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
            DiagnosticsLog.write(
                "showcase: ready — \(viewModel.profiles.count) profiles, \(viewModel.totalClicks) clicks; quit with ⌘Q")
        }

        /// Runs `stagedClicks` clicks on the no-op poster at a point clear of the window and the screen corners, so the
        /// counter and the last stop reason look like real use.
        private func stageRun(avoiding window: NSWindow) async {
            let geometry = ScreenGeometry.current()
            let screen = geometry.cgScreenFrames.first ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            let windowFrame = geometry.cgRect(fromAppKit: window.frame).insetBy(dx: -40, dy: -40)
            let left = CGPoint(x: screen.minX + 60, y: screen.midY)
            let point = windowFrame.contains(left) ? CGPoint(x: screen.maxX - 60, y: screen.midY) : left
            viewModel.configuration = ClickConfiguration(
                clickType: .left,
                interval: ClickInterval(milliseconds: 1),
                target: .fixed(point),
                stopCondition: .afterClicks(stagedClicks))
            viewModel.start()
            for _ in 0..<100 where viewModel.isRunning || viewModel.totalClicks < stagedClicks {
                try? await Task.sleep(for: .milliseconds(100))
            }
            DiagnosticsLog.write("showcase: staged run ended with \(viewModel.totalClicks) clicks")
        }
    }
#endif
