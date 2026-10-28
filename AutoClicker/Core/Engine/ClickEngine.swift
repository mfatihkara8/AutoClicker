import CoreGraphics
import Dispatch
import os

/// Runs click sessions: drives a `ClickScheduler` and turns each tick into a posted click.
///
/// On every tick, on the engine's serial click queue, it:
/// 1. reads the cursor and resolves the target (`.currentCursor` uses the cursor; a tick with no readable cursor is
///    skipped; `.fixed(p)` uses `p`),
/// 2. asks the failsafe what to do (`nil` failsafe means always proceed),
/// 3. posts the click with the run's modifiers,
/// 4. increments the shared total `ClickCounter` and the run's own click count,
/// 5. checks the stop condition.
///
/// ## Counting
/// The injected `ClickCounter` is the UI's total and is never reset here; only the user's Reset button does that.
/// `.afterClicks(n)` counts the clicks of the current run only. Skipped ticks are not counted anywhere.
///
/// ## Stop condition timing
/// `.afterDuration(t)` is measured from the run start with `ContinuousClock`: the scheduler delivers no tick due
/// after `t` and ends the run at `t`, even while every tick is being skipped. `.afterClicks(n)` stops right after the
/// n-th posted click. A condition that is already satisfied at start (a limit of zero or less) ends the run at once.
///
/// ## Threading
/// All mutable state is guarded by one `OSAllocatedUnfairLock`, so `start`, `stop` and the read-only properties are
/// safe from any thread. The engine never hops to the main actor; the UI samples `isSkippingInsideOwnWindow` and the
/// counter instead. A click whose tick was already past its "still running?" check when `stop` was called may still be
/// posted; nothing after it is.
final class ClickEngine: Sendable {
    private struct State {
        var runID: UInt64 = 0
        var configuration: ClickConfiguration?
        var runClicks = 0
        var isSkippingInsideOwnWindow = false
        var onStop: (@Sendable (StopReason) -> Void)?
    }

    private let poster: any EventPosting
    private let counter: ClickCounter
    private let failsafe: (any FailsafeChecking)?
    private let cursorLocation: @Sendable () -> CGPoint?
    private let queue: DispatchQueue
    private let scheduler: ClickScheduler
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Creates an idle engine.
    ///
    /// - Parameters:
    ///   - poster: Posts the clicks.
    ///   - counter: The shared total counter. The engine only increments it.
    ///   - failsafe: Evaluated before every click; `nil` disables the failsafe checks.
    ///   - cursorLocation: Reads the cursor in CG global space, or `nil` if it cannot be read. Called on the click
    ///     queue.
    ///   - queue: The serial click queue that runs every tick and every `onStop` call.
    ///   - jitterOffset: Draws one tick's jitter offset; inject a deterministic function in tests.
    init(
        poster: any EventPosting,
        counter: ClickCounter,
        failsafe: (any FailsafeChecking)?,
        cursorLocation: @escaping @Sendable () -> CGPoint? = ScreenGeometry.currentCursorLocation,
        queue: DispatchQueue = DispatchQueue(label: "AutoClicker.ClickEngine", qos: .userInteractive),
        jitterOffset: @escaping @Sendable (ClickInterval) -> Duration = { $0.jitterOffset() }
    ) {
        self.poster = poster
        self.counter = counter
        self.failsafe = failsafe
        self.cursorLocation = cursorLocation
        self.queue = queue
        self.scheduler = ClickScheduler(queue: queue, jitterOffset: jitterOffset)
    }

    deinit {
        scheduler.stop()
    }

    /// Called exactly once per run with the reason it ended, on the click queue. Set it before calling `start(_:)`;
    /// the value current at stop time is used. Hop to the main actor inside the closure if needed.
    var onStop: (@Sendable (StopReason) -> Void)? {
        get { state.withLock { $0.onStop } }
        set { state.withLock { $0.onStop = newValue } }
    }

    /// Whether a run is active.
    var isRunning: Bool {
        state.withLock { $0.configuration != nil }
    }

    /// Whether the most recent tick was skipped because its target was inside one of the app's own windows.
    ///
    /// Cheap and thread-safe, meant to be sampled by the UI at 10–20 Hz. It is `false` while idle.
    var isSkippingInsideOwnWindow: Bool {
        state.withLock { $0.isSkippingInsideOwnWindow }
    }

    /// Starts a run with a snapshot of `configuration`. Does nothing if a run is already active.
    func start(_ configuration: ClickConfiguration) {
        let runID: UInt64? = state.withLock { state in
            guard state.configuration == nil else {
                return nil
            }
            state.runID &+= 1
            state.configuration = configuration
            state.runClicks = 0
            state.isSkippingInsideOwnWindow = false
            let runID = state.runID
            let limit: Duration? =
                if case .afterDuration(let duration) = configuration.stopCondition { duration } else { nil }
            // Started under the engine lock so a concurrent `stop` cannot slip in between and leave an orphaned
            // scheduler run behind. Lock order is always engine, then scheduler; the scheduler never calls back while
            // holding its own lock.
            scheduler.start(
                interval: configuration.interval,
                limit: limit,
                onTick: { [weak self] tick in
                    self?.handleTick(tick, runID: runID)
                },
                onLimit: { [weak self] in
                    self?.stop(reason: .conditionMet, runID: runID)
                })
            return runID
        }
        guard let runID else {
            return
        }
        if configuration.stopCondition.isSatisfied(clicks: 0, elapsed: .zero) {
            stop(reason: .conditionMet, runID: runID)
        }
    }

    /// Stops the active run and reports `reason` through `onStop`. Does nothing if no run is active, so `onStop` is
    /// never called twice for one run.
    func stop(reason: StopReason = .user) {
        stop(reason: reason, runID: nil)
    }

    // MARK: - Private

    /// Stops the run with `runID`, or whichever run is active when `runID` is `nil`. A stale tick of an earlier run
    /// therefore cannot stop a newer one.
    private func stop(reason: StopReason, runID: UInt64?) {
        let result: (stopped: Bool, onStop: (@Sendable (StopReason) -> Void)?) = state.withLock { state in
            guard state.configuration != nil, runID == nil || runID == state.runID else {
                return (false, nil)
            }
            state.configuration = nil
            state.isSkippingInsideOwnWindow = false
            scheduler.stop()
            return (true, state.onStop)
        }
        guard result.stopped, let onStop = result.onStop else {
            return
        }
        // Always asynchronous, so the callback never runs inside a caller's tick or lock and always on the queue.
        queue.async {
            onStop(reason)
        }
    }

    private func handleTick(_ tick: ClickScheduler.Tick, runID: UInt64) {
        let active = state.withLock { state in
            state.runID == runID ? state.configuration : nil
        }
        guard let configuration = active else {
            return
        }

        // The failsafe needs the cursor even for a fixed target (the corner check), so it is read once per tick.
        let needsCursor = configuration.target == .currentCursor || failsafe != nil
        let cursor = needsCursor ? cursorLocation() : nil
        let target: CGPoint? =
            switch configuration.target {
            case .currentCursor: cursor
            case .fixed(let point): point
            }

        if let target {
            switch failsafe?.evaluate(cursor: cursor, target: target) ?? .proceed {
            case .stopCornerReached:
                stop(reason: .cornerFailsafe, runID: runID)
                return
            case .skipInsideOwnWindow:
                setSkippingInsideOwnWindow(true, runID: runID)
            case .proceed:
                poster.post(configuration.clickType, at: target, modifiers: configuration.modifiers)
                counter.increment()
                state.withLock { state in
                    guard state.runID == runID else {
                        return
                    }
                    state.runClicks += 1
                    state.isSkippingInsideOwnWindow = false
                }
            }
        } else {
            // No readable cursor: nothing to click, and not an own-window skip.
            setSkippingInsideOwnWindow(false, runID: runID)
        }

        let runClicks = state.withLock { $0.runClicks }
        // The scheduled deadline, not the wakeup time, keeps `.afterDuration` deterministic: a tick due exactly at the
        // limit is the last one posted.
        if configuration.stopCondition.isSatisfied(clicks: runClicks, elapsed: tick.deadline) {
            stop(reason: .conditionMet, runID: runID)
        }
    }

    private func setSkippingInsideOwnWindow(_ isSkipping: Bool, runID: UInt64) {
        state.withLock { state in
            guard state.runID == runID, state.configuration != nil else {
                return
            }
            state.isSkippingInsideOwnWindow = isSkipping
        }
    }
}
