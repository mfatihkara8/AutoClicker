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
/// ## Start/stop shortcut
/// `activate()` registers the persisted `toggleHotkey`. `beginRecordingShortcut()` unregisters it while the recorder
/// waits for a key: Carbon delivers a registered hotkey before the app sees the key, so pressing the current shortcut
/// could not be recorded otherwise. When recording ends, whether the key was accepted, rejected or Esc cancelled it,
/// one shortcut is registered again: the new one, or the previous one if the validator or the system refused the new
/// one (ADR-008).
///
/// ## Idle cost
/// Nothing polls while idle: the sampling task exists only during a run, the debounced save only after an edit, the
/// countdown only while picking a location and the key monitor only while recording a shortcut.
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

    /// The global start/stop shortcut. It is loaded with the settings and saved as soon as it changes.
    private(set) var toggleHotkey: Hotkey

    /// Whether the view model is waiting for the user to press a new start/stop shortcut.
    private(set) var isRecordingShortcut = false

    /// Why the last shortcut change did not happen (a rejected key, or a shortcut owned by another app), or `nil`.
    /// Cleared when recording begins again or the shortcut is reset.
    private(set) var shortcutWarning: String?

    /// Whether a run is active. It turns `false` once the engine has reported the end of the run.
    private(set) var isRunning = false

    /// The total number of clicks posted, sampled while running. Only `resetCounter()` sets it back to zero.
    private(set) var totalClicks: Int

    /// Why the most recent run ended, or `nil` before the first run and while a run is active.
    private(set) var lastStopReason: StopReason?

    /// Whether the engine is currently skipping clicks because the target lies inside one of the app's own windows.
    /// Clicking resumes on its own once the target leaves the window.
    private(set) var isTargetInsideOwnWindow = false

    /// A warning to show when the start/stop shortcut could not be registered, or `nil` when it works.
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

    /// Whether Change… can start recording a new shortcut. Like the other settings, the shortcut is locked while
    /// running.
    var canChangeShortcut: Bool {
        !isRunning
    }

    /// The display name of the start/stop shortcut for hints, or `nil` while it could not be registered, so the menu
    /// bar does not advertise a shortcut that does nothing.
    var advertisedToggleHotkeyName: String? {
        hotkeyWarning == nil ? toggleHotkey.displayName : nil
    }

    /// Whether the start/stop shortcut is the default F6, in which case Reset has nothing to do.
    var isDefaultShortcut: Bool {
        toggleHotkey == .f6
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
    @ObservationIgnored private let shortcutRecorder: any ShortcutRecording
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
    ///   - hotkeys: Registers the start/stop shortcut for the whole app lifetime and ESC while running.
    ///   - shortcutRecorder: Captures the next key press when the user changes the start/stop shortcut.
    ///   - permissionManager: The source of the Accessibility trust state.
    ///   - settingsStore: Loads the configuration and the start/stop shortcut now and saves every change.
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
        shortcutRecorder: any ShortcutRecording,
        permissionManager: PermissionManager,
        settingsStore: SettingsStore,
        geometrySnapshot: @escaping @MainActor () -> ScreenGeometry = { ScreenGeometry.current() },
        ownWindowFrames: @escaping @MainActor (ScreenGeometry) -> [CGRect] = {
            FailsafeMonitor.ownWindowFrames(geometry: $0)
        },
        cursorLocation: @escaping @MainActor () -> CGPoint? = { ScreenGeometry.currentCursorLocation() },
        // The low end of the 10–20 Hz range: every sample re-renders the counter, which is most of the CPU a run costs
        // (SC-6).
        samplingInterval: Duration = .seconds(1) / 10,
        permissionCheckInterval: Duration = .seconds(1),
        saveDebounce: Duration = .milliseconds(500),
        countdownTick: Duration = .seconds(1)
    ) {
        self.engine = engine
        self.counter = counter
        self.failsafe = failsafe
        self.hotkeys = hotkeys
        self.shortcutRecorder = shortcutRecorder
        self.permissionManager = permissionManager
        self.settingsStore = settingsStore
        self.geometrySnapshot = geometrySnapshot
        self.ownWindowFrames = ownWindowFrames
        self.cursorLocation = cursorLocation
        self.samplingInterval = samplingInterval
        self.permissionCheckInterval = permissionCheckInterval
        self.saveDebounce = saveDebounce
        self.countdownTick = countdownTick
        let settings = settingsStore.load()
        self.configuration = settings.configuration
        self.toggleHotkey = settings.toggleHotkey
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
        shortcutRecorder.cancel()
        hotkeys.unregister(.escape)
        if isActivated {
            hotkeys.unregister(toggleHotkey)
        }
        // A run must not outlive its owner; the callback finds `self` gone and does nothing.
        engine.stop()
    }

    // MARK: - Lifecycle

    /// Registers the persisted start/stop shortcut. Call it once from the composition root; later calls do nothing.
    ///
    /// A registration failure is not fatal: it sets `hotkeyWarning` and the Start button keeps working.
    func activate() {
        guard !isActivated else { return }
        isActivated = true
        // A recording session in progress registers the shortcut itself when it ends.
        if !isRecordingShortcut {
            registerToggleHotkey()
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
        cancelRecordingShortcut()
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

    /// Starts when idle and stops with reason `.hotkey` when running. This is what the start/stop shortcut does.
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

    // MARK: - Start/stop shortcut

    /// Waits for the user to press a new start/stop shortcut, then validates, registers and saves it.
    ///
    /// Does nothing while running or while already recording. The current shortcut is unregistered until recording
    /// ends, so it can be recorded again. Esc cancels; a rejected key, or one the system refuses, keeps the previous
    /// shortcut and sets `shortcutWarning`.
    func beginRecordingShortcut() {
        guard canChangeShortcut, !isRecordingShortcut else { return }
        shortcutWarning = nil
        if isActivated {
            hotkeys.unregister(toggleHotkey)
        }
        isRecordingShortcut = true
        shortcutRecorder.begin { [weak self] key in
            self?.handleRecordedKey(key)
        }
        if !shortcutRecorder.isRecording {
            // The recorder could not install its monitor, so no key will ever arrive.
            isRecordingShortcut = false
            registerToggleHotkey()
            shortcutWarning = String(
                localized: "Could not listen for a new shortcut. Try again.",
                comment: "Warning shown when recording a new start/stop shortcut could not start.")
        }
    }

    /// Stops recording and restores the current shortcut. Does nothing when not recording.
    func cancelRecordingShortcut() {
        guard isRecordingShortcut else { return }
        shortcutRecorder.cancel()
        isRecordingShortcut = false
        registerToggleHotkey()
    }

    /// Goes back to F6 as the start/stop shortcut. Cancels a recording in progress; does nothing while running.
    ///
    /// If F6 cannot be registered, the current shortcut stays and `shortcutWarning` says why.
    func resetShortcut() {
        guard canChangeShortcut else { return }
        cancelRecordingShortcut()
        shortcutWarning = nil
        changeToggleHotkey(to: .f6)
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
            // Not fatal: the start/stop shortcut, the Stop button and the corner failsafe still stop the run.
            let shortcut = toggleHotkey.displayName
            emergencyStopWarning = String(
                localized:
                    "Esc is unavailable as an emergency stop. Use \(shortcut), the Stop button or a screen corner.",
                comment: """
                    Warning shown while clicking when the Esc emergency stop could not be registered; the argument is \
                    the start/stop shortcut, such as F6.
                    """)
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

    // MARK: - Private: start/stop shortcut

    /// Registers `toggleHotkey` and clears or sets `hotkeyWarning`. Does nothing before `activate()`.
    private func registerToggleHotkey() {
        guard isActivated else { return }
        do {
            try registerToggle(toggleHotkey)
            hotkeyWarning = nil
        } catch {
            let shortcut = toggleHotkey.displayName
            hotkeyWarning = String(
                localized: "\(shortcut) is used by another app. Use the Start button instead.",
                comment: """
                    Warning shown when the start/stop shortcut could not be registered; the argument is the \
                    shortcut, such as F6.
                    """)
        }
    }

    private func registerToggle(_ hotkey: Hotkey) throws {
        try hotkeys.register(hotkey) { [weak self] in
            self?.toggle()
        }
    }

    private func handleRecordedKey(_ key: RecordedKey) {
        guard isRecordingShortcut else { return }
        isRecordingShortcut = false
        switch ShortcutValidator.validate(key) {
        case .accepted(let hotkey):
            changeToggleHotkey(to: hotkey)
        case .rejected(.escapeReserved):
            // Esc is how the user cancels recording, not a rejected choice, so it gets no warning.
            registerToggleHotkey()
        case .rejected(let rejection):
            shortcutWarning = rejection.displayText
            registerToggleHotkey()
        }
    }

    /// Moves the registration from the current shortcut to `newHotkey` and saves it, or keeps the current one
    /// registered and sets `shortcutWarning` when the system refuses `newHotkey`.
    private func changeToggleHotkey(to newHotkey: Hotkey) {
        guard isActivated else {
            // Nothing is registered yet; `activate()` registers whatever is current by then.
            commitToggleHotkey(newHotkey)
            return
        }
        let previous = toggleHotkey
        // A no-op while recording, which already released it.
        hotkeys.unregister(previous)
        do {
            try registerToggle(newHotkey)
            hotkeyWarning = nil
            commitToggleHotkey(newHotkey)
        } catch {
            let shortcut = previous.displayName
            shortcutWarning = String(
                localized: "This shortcut is in use by another app. Keeping \(shortcut).",
                comment: """
                    Warning shown when a new start/stop shortcut could not be registered; the argument is the \
                    previous shortcut, which stays active.
                    """)
            registerToggleHotkey()
        }
    }

    /// Adopts `hotkey` and saves right away: a shortcut change is one deliberate action, not a stream of edits to
    /// debounce. The save also writes any configuration edit still waiting for its debounce.
    private func commitToggleHotkey(_ hotkey: Hotkey) {
        toggleHotkey = hotkey
        performSave()
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
        settingsStore.save(AppSettings(configuration: configuration, toggleHotkey: toggleHotkey))
    }
}
