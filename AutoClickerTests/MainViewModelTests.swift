import CoreGraphics
import Testing
import os

@testable import AutoClicker

@MainActor
struct MainViewModelTests {
    private typealias Harness = MainViewModelHarness

    /// Checks the clean-up every stop path must do, whatever triggered it.
    private func expectCleanStop(_ harness: Harness, reason: StopReason) {
        let viewModel = harness.viewModel
        #expect(viewModel.isRunning == false)
        #expect(viewModel.lastStopReason == reason)
        #expect(harness.engine.isRunning == false)
        #expect(harness.hotkeys.isRegistered(.escape) == false)
        #expect(harness.hotkeys.unregisterCalls.contains(.escape))
        #expect(viewModel.isSampling == false)
        #expect(viewModel.totalClicks == harness.counter.value)
    }

    // MARK: - Init and idle

    @Test func initLoadsTheSavedConfigurationWithoutSaving() throws {
        let harness = try Harness()
        let saved = Harness.configuration(milliseconds: 250, stopCondition: .afterClicks(7))
        harness.store.save(saved)
        let writesBefore = harness.defaults.setCallCount

        let viewModel = harness.viewModel

        #expect(viewModel.configuration == saved)
        #expect(harness.defaults.setCallCount == writesBefore)
    }

    @Test func initFallsBackToTheDefaultConfiguration() throws {
        let harness = try Harness()

        #expect(harness.viewModel.configuration == .default)
    }

    @Test func idleViewModelHasNoSystemSideEffects() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        #expect(viewModel.isRunning == false)
        #expect(viewModel.isSampling == false)
        #expect(viewModel.isPickingLocation == false)
        #expect(viewModel.lastStopReason == nil)
        #expect(harness.hotkeys.registerCalls.isEmpty)
        #expect(harness.engine.onStop != nil)
    }

    // MARK: - Start

    @Test func startIsANoOpWithoutPermission() throws {
        let harness = try Harness(isTrusted: false)
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()

        #expect(viewModel.canStart == false)
        viewModel.start()

        #expect(viewModel.isRunning == false)
        #expect(harness.engine.isRunning == false)
        #expect(harness.hotkeys.registerCalls.isEmpty)
        #expect(viewModel.isSampling == false)
    }

    @Test func startOrOpenSettingsPicksUpAGrantMadeWhileTheWindowWasClosed() throws {
        let harness = try Harness(isTrusted: false)
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        #expect(viewModel.isAccessibilityTrusted == false)

        // Granted in System Settings while nothing was polling.
        harness.checker.isTrusted = true
        viewModel.startOrOpenAccessibilitySettings()

        #expect(viewModel.isRunning)
        #expect(harness.environment.openedURLs.isEmpty)
        viewModel.stop()
    }

    @Test func startOrOpenSettingsOpensThePaneWhenPermissionIsMissing() throws {
        let harness = try Harness(isTrusted: false)
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()

        viewModel.startOrOpenAccessibilitySettings()

        #expect(viewModel.isRunning == false)
        #expect(harness.engine.isRunning == false)
        #expect(harness.environment.openedURLs == [PermissionManager.accessibilitySettingsURL].compactMap { $0 })
    }

    @Test func startRegistersEscapeAndRunsTheEngine() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()

        #expect(viewModel.canStart)
        viewModel.start()

        #expect(viewModel.isRunning)
        #expect(harness.engine.isRunning)
        #expect(harness.hotkeys.isRegistered(.escape))
        #expect(viewModel.isSampling)
        #expect(viewModel.emergencyStopWarning == nil)

        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    @Test func startPushesFreshFailsafeSnapshots() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        let window = CGRect(x: 600, y: 600, width: 50, height: 50)
        harness.environment.windowFrames = [window]
        viewModel.configuration = Harness.configuration()
        // The monitor starts out with no screens, so no corner exists before the view model pushes its snapshot.
        #expect(harness.failsafe.shouldStop(cursor: CGPoint(x: 1000, y: 0)) == false)

        viewModel.start()

        #expect(harness.failsafe.shouldStop(cursor: CGPoint(x: 1000, y: 0)))
        #expect(harness.failsafe.isInsideOwnWindow(CGPoint(x: 610, y: 610)))

        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    @Test func startClearsThePreviousStopReason() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.start()
        viewModel.stop()
        #expect(await harness.waitForStop())
        #expect(viewModel.lastStopReason == .user)

        viewModel.start()

        #expect(viewModel.lastStopReason == nil)
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    // MARK: - Stop paths

    @Test func stopButtonStopsWithUserReason() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.start()

        viewModel.stop()
        // The run ends only once the engine has reported it.
        #expect(viewModel.isRunning)
        #expect(await harness.waitForStop())

        expectCleanStop(harness, reason: .user)
    }

    @Test func escapeStopsWithEmergencyReason() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.start()

        #expect(harness.hotkeys.simulatePress(.escape))
        #expect(await harness.waitForStop())

        expectCleanStop(harness, reason: .emergencyEscape)
    }

    @Test func escapeStopsWithinOneClick() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        // A slow interval: the first click is due 100 ms after start, long after ESC is pressed.
        viewModel.configuration = Harness.configuration(milliseconds: 100)
        viewModel.start()

        #expect(harness.hotkeys.simulatePress(.escape))
        #expect(await harness.waitForStop())
        try await Task.sleep(for: .milliseconds(150))

        #expect(harness.poster.count == 0)
        expectCleanStop(harness, reason: .emergencyEscape)
    }

    @Test func stopConditionStopsWithConditionMetAndUnregistersEscape() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration(stopCondition: .afterClicks(3))

        viewModel.start()
        #expect(await harness.waitForStop())

        expectCleanStop(harness, reason: .conditionMet)
        #expect(viewModel.totalClicks == 3)
        #expect(harness.poster.count == 3)
    }

    @Test func cornerFailsafeStopsAndUnregistersEscape() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        // (0, 0) is a corner of the geometry the view model pushes into the monitor on start.
        harness.engineCursor.withLock { $0 = CGPoint(x: 0, y: 0) }
        viewModel.configuration = Harness.configuration()

        viewModel.start()
        #expect(await harness.waitForStop())

        expectCleanStop(harness, reason: .cornerFailsafe)
        #expect(harness.poster.count == 0)
    }

    @Test func permissionLossWhileRunningStopsWithPermissionLost() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.start()
        #expect(viewModel.isRunning)

        harness.checker.isTrusted = false
        #expect(await harness.waitForStop())

        expectCleanStop(harness, reason: .permissionLost)
        #expect(viewModel.canStart == false)
    }

    @Test func lateStopCallbackDoesNotOverwriteTheFinishedRun() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.start()
        viewModel.stop()
        #expect(await harness.waitForStop())

        // A callback that belongs to no active run, as a stale one from an earlier run would.
        harness.engine.onStop?(.cornerFailsafe)
        await drain(harness.engineQueue)
        try await Task.sleep(for: .milliseconds(20))

        #expect(viewModel.lastStopReason == .user)
        #expect(viewModel.isRunning == false)
    }

    // MARK: - F6

    @Test func activateRegistersOnlyF6() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        viewModel.activate()
        viewModel.activate()

        #expect(harness.hotkeys.registerCalls == [.f6])
        #expect(harness.hotkeys.isRegistered(.f6))
        #expect(harness.hotkeys.isRegistered(.escape) == false)
        #expect(viewModel.hotkeyWarning == nil)
    }

    @Test func f6TogglesStartAndStopWithHotkeyReason() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.activate()

        #expect(harness.hotkeys.simulatePress(.f6))
        #expect(viewModel.isRunning)
        #expect(harness.engine.isRunning)
        #expect(harness.hotkeys.isRegistered(.escape))

        #expect(harness.hotkeys.simulatePress(.f6))
        #expect(await harness.waitForStop())

        expectCleanStop(harness, reason: .hotkey)
        // F6 stays registered for the next run.
        #expect(harness.hotkeys.isRegistered(.f6))

        #expect(harness.hotkeys.simulatePress(.f6))
        #expect(viewModel.isRunning)
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    @Test func f6DoesNotStartWithoutPermission() throws {
        let harness = try Harness(isTrusted: false)
        let viewModel = harness.viewModel
        viewModel.activate()

        #expect(harness.hotkeys.simulatePress(.f6))

        #expect(viewModel.isRunning == false)
        #expect(harness.engine.isRunning == false)
    }

    @Test func f6RegistrationFailureShowsAWarningAndStartStillWorks() async throws {
        let harness = try Harness()
        harness.hotkeys.registrationErrors[.f6] = .registrationFailed(.f6, status: -9878)
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()

        viewModel.activate()

        #expect(viewModel.hotkeyWarning != nil)
        viewModel.start()
        #expect(viewModel.isRunning)
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    // MARK: - ESC registration failure

    @Test func escapeRegistrationFailureKeepsRunningWithAWarning() async throws {
        let harness = try Harness()
        harness.hotkeys.registrationErrors[.escape] = .registrationFailed(.escape, status: -9878)
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()

        viewModel.start()

        #expect(viewModel.isRunning)
        #expect(harness.engine.isRunning)
        #expect(viewModel.emergencyStopWarning != nil)

        viewModel.stop()
        #expect(await harness.waitForStop())
        #expect(viewModel.emergencyStopWarning == nil)
    }

    // MARK: - Counter

    @Test func totalClicksIsSampledWhileRunningAndFinalAfterStop() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.start()

        #expect(await waitUntilOnMainActor { viewModel.totalClicks >= 3 })
        #expect(viewModel.isRunning)

        viewModel.stop()
        #expect(await harness.waitForStop())
        let final = viewModel.totalClicks
        #expect(final == harness.counter.value)
        #expect(final == harness.poster.count)

        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.totalClicks == final)
    }

    @Test func resetCounterZeroesTheTotal() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration(stopCondition: .afterClicks(3))
        viewModel.start()
        #expect(await harness.waitForStop())
        #expect(viewModel.totalClicks == 3)

        viewModel.resetCounter()

        #expect(viewModel.totalClicks == 0)
        #expect(harness.counter.value == 0)
    }

    @Test func startDoesNotResetTheTotal() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration(stopCondition: .afterClicks(3))
        viewModel.start()
        #expect(await harness.waitForStop())

        viewModel.configuration = Harness.configuration(stopCondition: .afterClicks(2))
        viewModel.start()
        #expect(await harness.waitForStop())

        #expect(viewModel.totalClicks == 5)
        #expect(viewModel.lastStopReason == .conditionMet)
    }

    // MARK: - Own-window protection

    @Test func ownWindowFlagPropagatesAndClickingResumes() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        harness.environment.windowFrames = [CGRect(x: 0, y: 0, width: 300, height: 300)]
        viewModel.configuration = Harness.configuration()

        viewModel.start()
        #expect(await waitUntilOnMainActor { viewModel.isTargetInsideOwnWindow })
        #expect(harness.poster.count == 0)

        // The window moves away from the target; sampling pushes the new frames and clicking resumes on its own.
        harness.environment.windowFrames = [CGRect(x: 600, y: 600, width: 100, height: 100)]
        let poster = harness.poster
        #expect(await waitUntilOnMainActor { !viewModel.isTargetInsideOwnWindow && poster.count > 0 })
        #expect(viewModel.isRunning)

        viewModel.stop()
        #expect(await harness.waitForStop())
        #expect(viewModel.isTargetInsideOwnWindow == false)
    }

    // MARK: - Sampling

    @Test func samplingRunsOnlyWhileRunning() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        #expect(viewModel.isSampling == false)

        viewModel.start()
        #expect(viewModel.isSampling)
        viewModel.stop()
        #expect(await harness.waitForStop())
        #expect(viewModel.isSampling == false)

        // Nothing reads the screens any more once the run has ended.
        let reads = harness.environment.geometryReads
        try await Task.sleep(for: .milliseconds(30))
        #expect(harness.environment.geometryReads == reads)
    }

    // MARK: - Saving

    @Test func rapidChangesAreSavedOnceAfterTheDebounce() async throws {
        let harness = try Harness(saveDebounce: .milliseconds(50))
        let viewModel = harness.viewModel
        let defaults = harness.defaults

        for milliseconds in 1...5 {
            viewModel.configuration.interval = ClickInterval(milliseconds: milliseconds * 100)
        }
        #expect(defaults.setCallCount == 0)

        #expect(await waitUntilOnMainActor { defaults.setCallCount >= 1 })
        try await Task.sleep(for: .milliseconds(150))

        #expect(defaults.setCallCount == 1)
        #expect(harness.store.load().interval == ClickInterval(milliseconds: 500))
    }

    @Test func settingTheSameConfigurationDoesNotSave() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        viewModel.configuration = viewModel.configuration
        try await Task.sleep(for: .milliseconds(80))

        #expect(harness.defaults.setCallCount == 0)
    }

    @Test func flushWritesThePendingSaveImmediately() async throws {
        let harness = try Harness(saveDebounce: .milliseconds(50))
        let viewModel = harness.viewModel
        let changed = Harness.configuration(milliseconds: 750)

        viewModel.configuration = changed
        viewModel.flushPendingSave()

        #expect(harness.defaults.setCallCount == 1)
        #expect(harness.store.load() == changed)

        // The debounced write was cancelled, and a second flush has nothing to write.
        try await Task.sleep(for: .milliseconds(150))
        viewModel.flushPendingSave()
        #expect(harness.defaults.setCallCount == 1)
    }

    // MARK: - Pick Location

    @Test func pickLocationStoresTheCursorAfterTheCountdown() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel
        let clock = ContinuousClock()
        let started = clock.now

        viewModel.pickLocation()
        #expect(viewModel.pickLocationCountdown == 3)
        #expect(viewModel.isPickingLocation)

        #expect(await waitUntilOnMainActor { !viewModel.isPickingLocation })

        #expect(clock.now - started >= .milliseconds(30))
        #expect(viewModel.configuration.target == .fixed(CGPoint(x: 321, y: 654)))
    }

    @Test func cancelledPickLocationLeavesTheTargetUnchanged() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel

        viewModel.pickLocation()
        viewModel.cancelPickLocation()

        #expect(viewModel.pickLocationCountdown == nil)
        try await Task.sleep(for: .milliseconds(80))
        #expect(viewModel.pickLocationCountdown == nil)
        #expect(viewModel.configuration.target == .currentCursor)
        #expect(harness.defaults.setCallCount == 0)
    }

    @Test func pickLocationWithoutACursorLeavesTheTargetUnchanged() async throws {
        let harness = try Harness(countdownTick: .milliseconds(5))
        harness.environment.pickCursor = nil
        let viewModel = harness.viewModel

        viewModel.pickLocation()
        #expect(await waitUntilOnMainActor { !viewModel.isPickingLocation })

        #expect(viewModel.configuration.target == .currentCursor)
    }

    @Test func pickLocationIsIgnoredWhileRunning() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.start()

        viewModel.pickLocation()

        #expect(viewModel.pickLocationCountdown == nil)
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    @Test func startCancelsAPickLocationInProgress() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.pickLocation()

        viewModel.start()

        #expect(viewModel.pickLocationCountdown == nil)
        try await Task.sleep(for: .milliseconds(60))
        #expect(viewModel.configuration.target == .fixed(Harness.target))
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    // MARK: - Lifetime

    @Test func releasingTheViewModelStopsTheRunAndUnregistersHotkeys() async throws {
        let harness = try Harness()
        var viewModel: MainViewModel? = harness.makeViewModel()
        viewModel?.configuration = Harness.configuration()
        viewModel?.activate()
        viewModel?.start()
        #expect(harness.engine.isRunning)

        viewModel = nil

        #expect(harness.engine.isRunning == false)
        #expect(harness.hotkeys.registeredHotkeys.isEmpty)
    }
}
