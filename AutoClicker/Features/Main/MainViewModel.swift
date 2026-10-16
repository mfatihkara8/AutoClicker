import CoreGraphics
import Foundation
import Observation

/// The UI state and intents of the main window and, later, the menu bar extra.
///
/// It is the only type that talks to the engine. It owns the editable `ClickConfiguration`, starts and stops runs,
/// samples the shared `ClickCounter` at 10–20 Hz while a run is active, and saves the configuration with a short
/// debounce.
///
/// ## Run lifecycle
/// `start()` checks permission, snapshots the configuration, pushes fresh screen and window snapshots into the
/// `FailsafeMonitor`, registers the scoped ESC hotkey, starts the engine and starts one sampling task. Every stop,
/// whoever triggers it, goes through `ClickEngine.stop(reason:)` and comes back through `ClickEngine.onStop`, so the
/// clean-up (unregister ESC, cancel sampling, read the final count, publish the reason) lives in one place.
/// `isRunning` therefore stays `true` until that callback arrives, which takes well under a millisecond.
///
/// ## Idle cost
/// Nothing polls while idle: the sampling task exists only during a run, the debounced save only after an edit and
/// the countdown only while picking a location.
@Observable @MainActor
final class MainViewModel {
    /// The number of countdown steps shown by `pickLocation()` before the cursor is captured.
    static let pickLocationCountdownStart = 3

    // MARK: - State

    /// The settings for the next run. Every change is saved after a short debounce; a running engine keeps the
    /// snapshot it was started with.
    var configuration: ClickConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            scheduleSave()
        }
    }

    /// Whether a run is active. It turns `false` once the engine has reported the end of the run.
    private(set) var isRunning = false

    /// The total number of clicks posted, sampled while running. Only `resetCounter()` sets it back to zero.
    private(set) var totalClicks: Int

    /// Why the most recent run ended, or `nil` before the first run and while a run is active.
    private(set) var lastStopReason: StopReason?

    /// Whether the engine is currently skipping clicks because the target lies inside one of the app's own windows.
    /// Clicking resumes on its own once the target leaves the window.
    private(set) var isTargetInsideOwnWindow = false

    /// A warning to show when F6 could not be registered, or `nil` when the hotkey works.
    private(set) var hotkeyWarning: String?

    /// A warning to show while a run is active without the ESC emergency stop, or `nil` when ESC works.
    private(set) var emergencyStopWarning: String?

    /// The remaining seconds of the Pick Location countdown (3, 2, 1), or `nil` when no pick is in progress.
    private(set) var pickLocationCountdown: Int?

    /// Whether the app is trusted for Accessibility, as last observed by the permission manager.
    var isAccessibilityTrusted: Bool {
        permissionManager.isTrusted
    }

    /// Whether `start()` can begin a run. The Start control is disabled while this is `false`.
    var canStart: Bool {
        isAccessibilityTrusted
    }

    /// Whether a Pick Location countdown is in progress.
    var isPickingLocation: Bool {
        pickLocationCountdown != nil
    }

    /// Whether the sampling task exists. It does only while a run is active, which keeps idle CPU at ~0%.
    var isSampling: Bool {
        samplingTask != nil
    }

    // MARK: - Dependencies

    @ObservationIgnored private let engine: ClickEngine
    @ObservationIgnored private let counter: ClickCounter
    @ObservationIgnored private let failsafe: FailsafeMonitor
    @ObservationIgnored private let hotkeys: any HotkeyProviding
    @ObservationIgnored private let permissionManager: PermissionManager
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let geometrySnapshot: @MainActor () -> ScreenGeometry
    @ObservationIgnored private let ownWindowFrames: @MainActor (ScreenGeometry) -> [CGRect]
    @ObservationIgnored private let cursorLocation: @MainActor () -> CGPoint?
    @ObservationIgnored private let samplingInterval: Duration
    @ObservationIgnored private let permissionCheckInterval: Duration
    @ObservationIgnored private let saveDebounce: Duration
    @ObservationIgnored private let countdownTick: Duration
    @ObservationIgnored private let clock = ContinuousClock()

    // MARK: - Owned tasks and bookkeeping

    @ObservationIgnored private var samplingTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var pickLocationTask: Task<Void, Never>?
    @ObservationIgnored private var lastPermissionCheck: ContinuousClock.Instant
    @ObservationIgnored private var isActivated = false
    /// Runs started by this view model whose `onStop` has not arrived yet. The engine reports exactly one stop per
    /// run, in order, so only the callback that brings this back to zero belongs to the current run; any earlier one
    /// is stale and ignored.
    @ObservationIgnored private var pendingStopCallbacks = 0

    /// Creates the view model and loads the saved configuration.
    ///
    /// Creating it has no system side effects: hotkeys are registered by `activate()` and `start()` only.
    ///
    /// - Parameters:
    ///   - engine: The click engine. Its `onStop` is taken over by this view model.
    ///   - counter: The total counter the engine increments.
    ///   - failsafe: The monitor the engine evaluates; this view model keeps its snapshots current.
    ///   - hotkeys: Registers F6 for the whole app lifetime and ESC while running.
    ///   - permissionManager: The source of the Accessibility trust state.
    ///   - settingsStore: Loads the configuration now and saves every change.
    ///   - geometrySnapshot: Reads the screen configuration; injected so tests need no real displays.
    ///   - ownWindowFrames: Snapshots the app's own window frames in CG space for a geometry.
    ///   - cursorLocation: Reads the cursor in CG global space for Pick Location.
    ///   - samplingInterval: How often the counter and flags are sampled while running (10–20 Hz).
    ///   - permissionCheckInterval: How often trust is re-checked while running.
    ///   - saveDebounce: How long the configuration must stay unchanged before it is saved.
    ///   - countdownTick: The length of one Pick Location countdown step.
    init(
        engine: ClickEngine,
        counter: ClickCounter,
        failsafe: FailsafeMonitor,
        hotkeys: any HotkeyProviding,
        permissionManager: PermissionManager,
        settingsStore: SettingsStore,
        geometrySnapshot: @escaping @MainActor () -> ScreenGeometry = { ScreenGeometry.current() },
        ownWindowFrames: @escaping @MainActor (ScreenGeometry) -> [CGRect] = {
            FailsafeMonitor.ownWindowFrames(geometry: $0)
        },
        cursorLocation: @escaping @MainActor () -> CGPoint? = { ScreenGeometry.currentCursorLocation() },
        samplingInterval: Duration = .seconds(1) / 15,
        permissionCheckInterval: Duration = .seconds(1),
        saveDebounce: Duration = .milliseconds(500),
        countdownTick: Duration = .seconds(1)
    ) {
        self.engine = engine
        self.counter = counter
        self.failsafe = failsafe
        self.hotkeys = hotkeys
        self.permissionManager = permissionManager
        self.settingsStore = settingsStore
        self.geometrySnapshot = geometrySnapshot
        self.ownWindowFrames = ownWindowFrames
        self.cursorLocation = cursorLocation
        self.samplingInterval = samplingInterval
        self.permissionCheckInterval = permissionCheckInterval
        self.saveDebounce = saveDebounce
        self.countdownTick = countdownTick
        self.configuration = settingsStore.load()
        self.totalClicks = counter.value
        self.lastPermissionCheck = clock.now

        // Set once for the lifetime of the view model. The engine calls it on its click queue; the clean-up must run
        // on the main actor, where all the state above lives.
        engine.onStop = { [weak self] reason in
            Task { @MainActor [weak self] in
                self?.handleEngineStop(reason)
            }
        }
    }

    // `isolated` so the hotkey provider, which is main-actor bound, can be cleaned up here.
    isolated deinit {
        samplingTask?.cancel()
        saveTask?.cancel()
        pickLocationTask?.cancel()
        hotkeys.unregister(.escape)
        if isActivated {
            hotkeys.unregister(.f6)
        }
        // A run must not outlive its owner; the callback finds `self` gone and does nothing.
        engine.stop()
    }

    // MARK: - Lifecycle

    /// Registers the F6 start/stop hotkey. Call it once from the composition root; later calls do nothing.
    ///
    /// A registration failure is not fatal: it sets `hotkeyWarning` and the Start button keeps working.
    func activate() {
        guard !isActivated else { return }
        isActivated = true
        do {
            try hotkeys.register(.f6) { [weak self] in
                self?.toggle()
            }
            hotkeyWarning = nil
        } catch {
            hotkeyWarning = String(
                localized: "F6 is used by another app. Use the Start button instead.",
                comment: "Warning shown when the F6 start/stop hotkey could not be registered.")
        }
    }

    // MARK: - Run intents

    /// Starts a run with the current configuration.
    ///
    /// Does nothing while running or while Accessibility permission is missing. Cancels a Pick Location countdown in
    /// progress, so the target cannot change under a running engine.
    func start() {
        guard !isRunning, !engine.isRunning else { return }
        // Polling stops once trust is granted, so the cached value may be stale; re-read it before every start.
        permissionManager.refresh()
        guard permissionManager.isTrusted else { return }

        cancelPickLocation()
        let snapshot = configuration
        pushFailsafeSnapshots()
        registerEmergencyStop()

        lastStopReason = nil
        isTargetInsideOwnWindow = false
        isRunning = true
        lastPermissionCheck = clock.now
        pendingStopCallbacks += 1
        engine.start(snapshot)
        startSampling()
    }

    /// Stops the active run with reason `.user`. Does nothing while idle.
    func stop() {
        requestStop(.user)
    }

    /// Starts when idle and stops with reason `.hotkey` when running. This is what F6 does.
    func toggle() {
        if isRunning {
            requestStop(.hotkey)
        } else {
            start()
        }
    }

    /// Sets the total click count back to zero. Starting a run never does this.
    func resetCounter() {
        counter.reset()
        totalClicks = 0
    }

    // MARK: - Pick Location

    /// Starts a 3-second countdown, then stores the cursor position as a fixed target.
    ///
    /// Does nothing while running or while a countdown is already in progress. If the cursor cannot be read, the
    /// target stays unchanged.
    func pickLocation() {
        guard !isRunning, pickLocationTask == nil else { return }
        let start = Self.pickLocationCountdownStart
        let tick = countdownTick
        pickLocationCountdown = start
        pickLocationTask = Task { [weak self] in
            for remaining in stride(from: start, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self?.pickLocationCountdown = remaining
                do {
                    try await Task.sleep(for: tick)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            self?.finishPickLocation()
        }
    }

    /// Cancels a Pick Location countdown in progress and leaves the target unchanged.
    func cancelPickLocation() {
        pickLocationTask?.cancel()
        pickLocationTask = nil
        pickLocationCountdown = nil
    }

    // MARK: - Persistence

    /// Writes a pending debounced save right away. Call it before the app terminates so a quick quit loses nothing.
    func flushPendingSave() {
        guard saveTask != nil else { return }
        performSave()
    }

    // MARK: - Permission

    /// Starts keeping the permission state current. Call it when the window becomes visible.
    func startPermissionMonitoring() {
        permissionManager.startMonitoring()
    }

    /// Stops the visible-window permission polling. Call it when the window is hidden.
    func stopPermissionMonitoring() {
        permissionManager.stopMonitoring()
    }

    /// Shows the system Accessibility prompt. Call it only from an explicit user action.
    func requestAccessibilityPermission() {
        permissionManager.requestPermission()
    }

    /// Opens the Accessibility pane of System Settings.
    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
    }

    /// Starts a run, or opens the Accessibility pane when permission is still missing.
    ///
    /// The menu bar uses this instead of a disabled Start item: permission is polled only while the main window is
    /// visible, so with the window closed the cached state can be stale. `start()` re-reads it, and only when trust is
    /// really missing does the user get sent to System Settings.
    func startOrOpenAccessibilitySettings() {
        start()
        if !isRunning && !isAccessibilityTrusted {
            openAccessibilitySettings()
        }
    }

    // MARK: - Private: running

    private func requestStop(_ reason: StopReason) {
        guard isRunning else { return }
        engine.stop(reason: reason)
    }

    private func registerEmergencyStop() {
        do {
            try hotkeys.register(.escape) { [weak self] in
                self?.requestStop(.emergencyEscape)
            }
            emergencyStopWarning = nil
        } catch {
            // Not fatal: F6, the Stop button and the corner failsafe still stop the run.
            emergencyStopWarning = String(
                localized: "Esc is unavailable as an emergency stop. Use F6, the Stop button or a screen corner.",
                comment: "Warning shown while clicking when the Esc emergency-stop hotkey could not be registered.")
        }
    }

    /// Hands the failsafe fresh main-actor snapshots. The window may have moved and screens may have changed since
    /// the last call.
    private func pushFailsafeSnapshots() {
        let geometry = geometrySnapshot()
        failsafe.update(geometry: geometry)
        failsafe.update(ownWindowFrames: ownWindowFrames(geometry))
    }

    private func startSampling() {
        samplingTask?.cancel()
        let interval = samplingInterval
        // Inherits main-actor isolation, so `sample()` runs where the state lives.
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                // A thrown error only means cancellation, which the loop condition handles.
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                self.sample()
            }
        }
    }

    private func sample() {
        let clicks = counter.value
        if clicks != totalClicks {
            totalClicks = clicks
        }
        let isSkipping = engine.isSkippingInsideOwnWindow
        if isSkipping != isTargetInsideOwnWindow {
            isTargetInsideOwnWindow = isSkipping
        }
        pushFailsafeSnapshots()

        let now = clock.now
        if now - lastPermissionCheck >= permissionCheckInterval {
            lastPermissionCheck = now
            permissionManager.refresh()
            if !permissionManager.isTrusted {
                engine.stop(reason: .permissionLost)
            }
        }
    }

    private func handleEngineStop(_ reason: StopReason) {
        guard pendingStopCallbacks > 0 else { return }
        pendingStopCallbacks -= 1
        guard pendingStopCallbacks == 0 else { return }

        samplingTask?.cancel()
        samplingTask = nil
        hotkeys.unregister(.escape)
        emergencyStopWarning = nil
        // The engine queues `onStop` behind any tick still in flight, so this is the final count of the run.
        totalClicks = counter.value
        isTargetInsideOwnWindow = false
        isRunning = false
        lastStopReason = reason
    }

    // MARK: - Private: pick location and saving

    private func finishPickLocation() {
        pickLocationTask = nil
        pickLocationCountdown = nil
        if let point = cursorLocation() {
            configuration.target = .fixed(point)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let delay = saveDebounce
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            // A flush may have cancelled this task after its sleep ended but before it resumed.
            guard !Task.isCancelled else { return }
            self?.performSave()
        }
    }

    private func performSave() {
        saveTask?.cancel()
        saveTask = nil
        settingsStore.save(configuration)
    }
}
