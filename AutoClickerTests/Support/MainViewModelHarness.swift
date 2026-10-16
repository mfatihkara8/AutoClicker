import CoreGraphics
import Dispatch
import Foundation
import os

@testable import AutoClicker

/// A `MainViewModel` wired to a real `ClickEngine` and `FailsafeMonitor` on top of test doubles.
///
/// Nothing touches the real system: clicks go to `MockEventPoster`, hotkeys to `MockHotkeyProvider`, trust comes from
/// `MockPermissionChecker`, settings live in a throwaway `UserDefaults` suite (removed in `deinit`), and the screen,
/// window and cursor readers return the values held here. All durations are a few milliseconds so the suite stays
/// fast.
@MainActor
final class MainViewModelHarness {
    /// The single test screen: 1000 × 800 points, so its CG corners are (0, 0), (1000, 0), (0, 800) and (1000, 800).
    static let geometry = ScreenGeometry(appKitScreenFrames: [CGRect(x: 0, y: 0, width: 1000, height: 800)])
    /// A fixed target well away from every corner.
    static let target = CGPoint(x: 100, y: 100)

    /// Values read by the view model's main-actor closures. A separate object, so those closures do not retain the
    /// harness that owns the view model.
    @MainActor
    final class Environment {
        var pickCursor: CGPoint? = CGPoint(x: 321, y: 654)
        var windowFrames: [CGRect] = []
        var geometryReads = 0
    }

    let suiteName = "MainViewModelTests.\(UUID().uuidString)"
    let defaults: CountingUserDefaults
    let store: SettingsStore
    let poster = MockEventPoster()
    let counter = ClickCounter()
    let failsafe = FailsafeMonitor(geometry: ScreenGeometry(appKitScreenFrames: []))
    let engineQueue = DispatchQueue(label: "MainViewModelTests.engine", qos: .userInteractive)
    let engineCursor = OSAllocatedUnfairLock<CGPoint?>(initialState: CGPoint(x: 500, y: 400))
    let engine: ClickEngine
    let hotkeys = MockHotkeyProvider()
    let checker: MockPermissionChecker
    let permissionManager: PermissionManager
    let environment = Environment()
    let saveDebounce: Duration
    let countdownTick: Duration

    private(set) lazy var viewModel = makeViewModel()

    init(
        isTrusted: Bool = true,
        saveDebounce: Duration = .milliseconds(30),
        countdownTick: Duration = .milliseconds(10)
    ) throws {
        guard let defaults = CountingUserDefaults(suiteName: suiteName) else {
            throw HarnessError.suiteUnavailable
        }
        self.defaults = defaults
        store = SettingsStore(defaults: defaults)
        checker = MockPermissionChecker(isTrusted: isTrusted)
        permissionManager = PermissionManager(checker: checker, pollInterval: .milliseconds(5), openURL: { _ in })
        let cursor = engineCursor
        engine = ClickEngine(
            poster: poster,
            counter: counter,
            failsafe: failsafe,
            cursorLocation: { cursor.withLock { $0 } },
            queue: engineQueue)
        self.saveDebounce = saveDebounce
        self.countdownTick = countdownTick
    }

    deinit {
        // `deinit` is nonisolated and cannot touch the non-Sendable `defaults`, so a fresh handle on the same suite
        // removes it.
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    /// Builds a new view model on the shared doubles. `viewModel` is the one most tests use.
    func makeViewModel() -> MainViewModel {
        let environment = environment
        return MainViewModel(
            engine: engine,
            counter: counter,
            failsafe: failsafe,
            hotkeys: hotkeys,
            permissionManager: permissionManager,
            settingsStore: store,
            geometrySnapshot: {
                environment.geometryReads += 1
                return Self.geometry
            },
            ownWindowFrames: { _ in environment.windowFrames },
            cursorLocation: { environment.pickCursor },
            samplingInterval: .milliseconds(5),
            permissionCheckInterval: .milliseconds(20),
            saveDebounce: saveDebounce,
            countdownTick: countdownTick)
    }

    /// A configuration that clicks the fixed `target` every `milliseconds`.
    static func configuration(milliseconds: Int = 2, stopCondition: StopCondition = .never) -> ClickConfiguration {
        ClickConfiguration(
            clickType: .left,
            interval: ClickInterval(milliseconds: milliseconds),
            target: .fixed(target),
            stopCondition: stopCondition)
    }

    /// Waits until the view model has processed the end of the run.
    func waitForStop() async -> Bool {
        let viewModel = viewModel
        return await waitUntilOnMainActor { !viewModel.isRunning }
    }

    enum HarnessError: Error {
        case suiteUnavailable
    }
}
