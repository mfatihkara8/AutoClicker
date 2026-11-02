#if DIAGNOSTICS
    import AppKit

    /// An end-to-end check with real events (`AUTOCLICKER_LIVE_CHECK=<frame file>`), driven by `scripts/live-check.sh`
    /// against the window of `scripts/click-target.swift`:
    /// 1. **Add Point:** opens Edit Points on the Click tab and, three times, puts the cursor on a known point inside
    ///    the target, presses Add Point and waits for the real 3-second countdown, then checks the appended point.
    /// 2. **Profiles:** saves "Live A" from that configuration, changes it and saves "Live B", then opens the menu bar
    ///    extra's Profiles submenu, reads its items and checkmarks, chooses "Live A" and checks it was applied.
    /// 3. **Live run:** with Accessibility trust, starts the configuration of "Live A" (the three points, 150 ms each,
    ///    left click with ⌘, offset 8, stop after 12 clicks) and waits for it to stop. Without trust it skips the run
    ///    and never prompts.
    ///
    /// Edit Points, Add Point, Done and the menu bar extra are pressed through the Accessibility API
    /// (`OwnAccessibilityClient`), so the real views and the real menu are exercised. While the menu is open, its
    /// Profiles items are read and chosen on SwiftUI's own `NSMenu` (`StatusItemMenu`). When a step cannot do that, it
    /// falls back to the view model intent the control calls, and the result says so. It writes `LiveCheckResult` as
    /// JSON and quits. The script compares the run with the clicks the target received.
    @MainActor
    final class LiveCheckDriver {
        private let viewModel: MainViewModel
        private let navigation: WindowNavigation
        private let frameFile: URL
        private let resultFile: URL
        private var result = LiveCheckResult()

        private let settleTime: Duration = .milliseconds(700)
        private let interval = 150
        private let clickLimit = 12
        private let offset = 8
        private let modifiers: ClickModifiers = [.command]

        init(viewModel: MainViewModel, navigation: WindowNavigation, frameFile: URL, resultFile: URL) {
            self.viewModel = viewModel
            self.navigation = navigation
            self.frameFile = frameFile
            self.resultFile = resultFile
        }

        func run() async {
            guard let window = await MainWindowLocator.waitForMainWindow() else {
                fail("the main window never appeared")
                return
            }
            guard let target = await readTargetFrames() else {
                fail("cannot read the target frames from \(frameFile.path)")
                return
            }
            result.accessibilityTrusted = AccessibilityPermissionChecker().isTrusted
            result.targetContent = LiveCheckResult.Point(target.content.origin)
            log("Accessibility trusted: \(result.accessibilityTrusted); target content \(target.content)")
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
            moveWindow(window, awayFrom: target.window)
            try? await Task.sleep(for: .seconds(1))

            let points = Self.points(in: target.content)
            await addPoints(points, window: window)
            let liveA = await checkProfiles()
            if result.accessibilityTrusted {
                await liveRun(profile: liveA, target: target.window)
            } else {
                note("live run skipped: the app is not trusted for Accessibility (no prompt was shown)")
            }
            finish()
        }

        // MARK: - Steps

        private func addPoints(_ points: [CGPoint], window: NSWindow) async {
            viewModel.configuration = ClickConfiguration(
                clickType: .left,
                interval: ClickInterval(milliseconds: interval),
                target: .sequence([]),
                stopCondition: .afterClicks(clickLimit),
                modifiers: modifiers,
                positionOffset: offset)
            navigation.selectedTab = .click
            try? await Task.sleep(for: settleTime)

            var viaAccessibility = false
            if result.accessibilityTrusted {
                viaAccessibility = await press("editPointsButton")
            }
            try? await Task.sleep(for: settleTime)
            result.addPoint.sheetOpened = window.attachedSheet != nil
            result.addPoint.method =
                viaAccessibility && result.addPoint.sheetOpened
                ? "Accessibility: pressed Edit Points… and Add Point in the real sheet"
                : "fallback: MainViewModel.addSequencePoint(), the Add Point button's action"
            log("add point: \(result.addPoint.method)")

            for point in points {
                result.addPoint.points.append(await addPoint(at: point, pressButton: result.addPoint.sheetOpened))
            }
            result.addPoint.passed =
                result.addPoint.points.count == points.count && result.addPoint.points.allSatisfy(\.passed)

            if window.attachedSheet != nil {
                let closed = await press("sequenceDoneButton")
                if !closed, let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
                try? await Task.sleep(for: settleTime)
            }
            if window.attachedSheet != nil {
                note("the Edit Points sheet did not close")
            }
        }

        private func addPoint(at point: CGPoint, pressButton: Bool) async -> LiveCheckResult.AddedPoint {
            var added = LiveCheckResult.AddedPoint(requested: LiveCheckResult.Point(point))
            let countBefore = sequencePoints.count
            CGWarpMouseCursorPosition(point)
            let started = ContinuousClock.now
            var pressed = false
            if pressButton {
                pressed = await press("addPointButton")
            }
            if !pressed {
                viewModel.addSequencePoint()
            }
            added.countdownStarted = viewModel.addSequencePointCountdown != nil
            // The countdown is 3 s; anything well beyond that is a failure.
            while viewModel.addSequencePointCountdown != nil, ContinuousClock.now - started < .seconds(8) {
                try? await Task.sleep(for: .milliseconds(20))
            }
            let elapsed = ContinuousClock.now - started
            added.countdownSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            added.cursorAtEnd = ScreenGeometry.currentCursorLocation().map(LiveCheckResult.Point.init)
            let points = sequencePoints
            if points.count == countBefore + 1, let last = points.last {
                added.appended = LiveCheckResult.Point(last.point)
                added.delayMilliseconds = last.delayMilliseconds
                let distance = hypot(last.point.x - point.x, last.point.y - point.y)
                added.distance = distance
                added.passed =
                    added.countdownStarted && distance <= 1 && last.delayMilliseconds == interval
                    && added.countdownSeconds >= 2.9
            }
            log(
                "add point at (\(point.x), \(point.y)): appended \(added.appended.map { "(\($0.x), \($0.y))" } ?? "none") "
                    + "after \(String(format: "%.2f", added.countdownSeconds)) s -> \(added.passed ? "ok" : "FAILED")")
            return added
        }

        /// Saves "Live A" and "Live B", then applies "Live A" from the menu bar extra. Returns "Live A".
        private func checkProfiles() async -> Profile? {
            var section = LiveCheckResult.Profiles()
            if let rejection = viewModel.saveNewProfile(named: "Live A") {
                note("saving Live A failed: \(rejection)")
            }
            let liveA = viewModel.activeProfile
            var changed = viewModel.configuration
            changed.modifiers = [.shift]
            changed.positionOffset = 30
            viewModel.configuration = changed
            if let rejection = viewModel.saveNewProfile(named: "Live B") {
                note("saving Live B failed: \(rejection)")
            }
            section.activeBefore = viewModel.activeProfile?.name
            section.chosen = "Live A"
            try? await Task.sleep(for: settleTime)

            do {
                guard result.accessibilityTrusted else {
                    throw OwnAccessibilityClient.Failure.notFound("Accessibility trust")
                }
                section.itemsBefore = try await withOpenMenu {
                    let items = try StatusItemMenu.profileItems()
                    try StatusItemMenu.chooseProfileItem(named: "Live A")
                    return items
                }
                section.method =
                    "real menu: pressed the menu bar extra through Accessibility; read and chose the Profiles items "
                    + "of its open NSMenu"
                try? await Task.sleep(for: settleTime)
                // Open it again to see the checkmark move.
                section.itemsAfter = try await withOpenMenu {
                    defer { StatusItemMenu.close() }
                    return try StatusItemMenu.profileItems()
                }
            } catch {
                note("the menu bar extra's menu failed (\(error)); used the menu's toggle bindings instead")
                section.method = "fallback: MenuBarContent's toggle bindings (activeProfileID == id / applyProfile)"
                section.itemsBefore = bindingItems()
                if let liveA {
                    viewModel.applyProfile(id: liveA.id)
                }
                section.itemsAfter = bindingItems()
            }
            try? await Task.sleep(for: settleTime)

            section.activeAfter = viewModel.activeProfile?.name
            section.configurationMatchesChosen = liveA.map { viewModel.configuration == $0.configuration } ?? false
            let names = Set(viewModel.profiles.map(\.name))
            func checkedOnly(_ name: String, in items: [StatusItemMenu.MenuItem]) -> Bool {
                Set(items.map(\.title)) == names && items.filter(\.isChecked).map(\.title) == [name]
            }
            section.passed =
                checkedOnly("Live B", in: section.itemsBefore) && checkedOnly("Live A", in: section.itemsAfter)
                && section.activeAfter == "Live A" && section.configurationMatchesChosen
            log(
                "profiles: \(section.method); before \(section.itemsBefore), after \(section.itemsAfter), "
                    + "active \(section.activeAfter ?? "none") -> \(section.passed ? "ok" : "FAILED")")
            result.profiles = section
            return liveA
        }

        private func liveRun(profile: Profile?, target: CGRect) async {
            var run = LiveCheckResult.Run()
            if let profile, viewModel.configuration != profile.configuration {
                note("the configuration was not Live A's after applying it; set it directly for the run")
                viewModel.configuration = profile.configuration
            }
            navigation.selectedTab = .main
            try? await Task.sleep(for: settleTime)

            let configuration = viewModel.configuration
            if case .sequence(let points) = configuration.target {
                run.points = points.map { LiveCheckResult.Point($0.point) }
            }
            run.positionOffset = configuration.positionOffset
            run.modifiers = configuration.modifiers
            run.clickType = "\(configuration.clickType)"
            if case .afterClicks(let limit) = configuration.stopCondition {
                run.expectedClicks = limit
            }
            let clearance = target.insetBy(dx: -CGFloat(offset) - 2, dy: -CGFloat(offset) - 2)
            let ownWindows = FailsafeMonitor.ownWindowFrames(geometry: .current())
            run.ownWindowsClear = !ownWindows.contains { $0.intersects(clearance) }
            if !run.ownWindowsClear {
                note("an own window overlaps the target: \(ownWindows); clicks there would be skipped")
            }

            let before = viewModel.totalClicks
            let started = ContinuousClock.now
            log("live run: starting \(run.expectedClicks) clicks at \(run.points.count) points")
            viewModel.start()
            run.started = viewModel.isRunning
            guard run.started else {
                note("start() did not start the live run")
                result.run = run
                return
            }
            while viewModel.isRunning, ContinuousClock.now - started < .seconds(20) {
                try? await Task.sleep(for: .milliseconds(50))
            }
            if viewModel.isRunning {
                note("the live run did not stop by itself within 20 s; stopped it")
                viewModel.stop()
                try? await Task.sleep(for: .milliseconds(500))
            }
            let elapsed = ContinuousClock.now - started
            run.durationSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            run.countedClicks = viewModel.totalClicks - before
            run.stopReason = viewModel.lastStopReason.map { "\($0)" }
            log("live run: \(run.countedClicks) clicks counted, stop reason \(run.stopReason ?? "none")")
            result.run = run
        }

        // MARK: - Helpers

        private struct TargetFrames: Decodable {
            struct Rect: Decodable {
                var x: Double
                var y: Double
                var width: Double
                var height: Double

                var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
            }
            var window: Rect
            var content: Rect
        }

        /// Waits up to 10 s for the click target to write its frames (CG global).
        private func readTargetFrames() async -> (window: CGRect, content: CGRect)? {
            for _ in 0..<100 {
                if let data = try? Data(contentsOf: frameFile),
                    let frames = try? JSONDecoder().decode(TargetFrames.self, from: data)
                {
                    return (frames.window.cgRect, frames.content.cgRect)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            return nil
        }

        /// Three points inside the target's content, far enough apart that an 8 pt offset cannot make one click look
        /// like another point's.
        private static func points(in content: CGRect) -> [CGPoint] {
            [
                CGPoint(x: content.minX + 80, y: content.minY + 80),
                CGPoint(x: content.midX, y: content.maxY - 60),
                CGPoint(x: content.maxX - 80, y: content.minY + 80),
            ]
            .map { CGPoint(x: $0.x.rounded(), y: $0.y.rounded()) }
        }

        /// Moves the main window to the side of the main display away from the target, so the own-window failsafe
        /// never skips a click and the window does not cover the target.
        private func moveWindow(_ window: NSWindow, awayFrom target: CGRect) {
            let geometry = ScreenGeometry.current()
            guard let screen = NSScreen.screens.first?.visibleFrame else { return }
            let targetAppKit = geometry.appKitRect(fromCG: target)
            let size = window.frame.size
            let x =
                targetAppKit.midX < screen.midX
                ? max(screen.maxX - size.width - 20, targetAppKit.maxX + 40)
                : min(screen.minX + 20, targetAppKit.minX - 40 - size.width)
            window.setFrameOrigin(CGPoint(x: x, y: screen.maxY - size.height - 20))
            log("main window moved to \(geometry.cgRect(fromAppKit: window.frame)) (CG)")
        }

        private var sequencePoints: [ClickPoint] {
            guard case .sequence(let points) = viewModel.configuration.target else { return [] }
            return points
        }

        /// The Profiles submenu as MenuBarContent builds it: one toggle per profile, on when it is the active one.
        private func bindingItems() -> [StatusItemMenu.MenuItem] {
            viewModel.profiles.map { profile in
                StatusItemMenu.MenuItem(
                    title: profile.name, isChecked: viewModel.activeProfileID == profile.id,
                    isEnabled: viewModel.canApplyProfile)
            }
        }

        /// Presses the element with `identifier` through the Accessibility API, retrying for up to 2 s while it is not
        /// there yet (SwiftUI may still be swapping a countdown back to its button). Returns whether it was pressed.
        private func press(_ identifier: String) async -> Bool {
            var lastError: (any Error)?
            for _ in 0..<20 {
                do {
                    try OwnAccessibilityClient.pressElement(identifier: identifier)
                    return true
                } catch {
                    lastError = error
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            note("pressing \(identifier) through Accessibility failed: \(lastError.map { "\($0)" } ?? "unknown")")
            return false
        }

        /// Presses the menu bar extra and runs `work` while its menu is open, then returns what `work` returned.
        ///
        /// The press runs the menu's tracking loop and only returns once the menu closes, so `work` runs from a run
        /// loop timer in the common modes, which the tracking loop keeps serving. It must close the menu, by choosing
        /// an item or with `StatusItemMenu.close()`; if it throws, the menu is closed for it.
        private func withOpenMenu<Value>(
            _ work: @escaping @MainActor @Sendable () throws -> Value
        ) async throws -> Value {
            let outcome = MenuOutcome<Value>()
            let timer = Timer(timeInterval: 0.6, repeats: false) { _ in
                MainActor.assumeIsolated {
                    do {
                        outcome.result = .success(try work())
                    } catch {
                        outcome.result = .failure(error)
                        StatusItemMenu.close()
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            defer { timer.invalidate() }
            try OwnAccessibilityClient.pressMenuBarExtra()
            // In case the press returned while the menu was still open.
            for _ in 0..<60 where outcome.result == nil {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard let result = outcome.result else {
                StatusItemMenu.close()
                throw OwnAccessibilityClient.Failure.notFound("an open menu within 3 s of pressing the menu bar extra")
            }
            return try result.get()
        }

        private func note(_ text: String) {
            result.notes.append(text)
            log(text)
        }

        private func log(_ text: String) {
            DiagnosticsLog.write("live check: \(text)")
        }

        private func fail(_ reason: String) {
            note("FAILED: \(reason)")
            finish()
        }

        private func finish() {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            do {
                try encoder.encode(result).write(to: resultFile, options: .atomic)
                log("result written to \(resultFile.path)")
            } catch {
                log("cannot write \(resultFile.path): \(error)")
            }
            NSApplication.shared.terminate(nil)
        }
    }

    /// What `withOpenMenu` hands back from its timer.
    @MainActor
    private final class MenuOutcome<Value> {
        var result: Result<Value, any Error>?
    }
#endif
