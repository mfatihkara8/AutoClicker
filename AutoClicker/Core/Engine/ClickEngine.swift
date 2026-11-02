import CoreGraphics
import Dispatch
import os

/// Runs click sessions: drives a `ClickScheduler` and turns each tick into a posted click.
///
/// On every tick, on the engine's serial click queue, it:
/// 1. reads the cursor and resolves the target: `.currentCursor` uses the cursor, and a tick with no readable cursor is
///    skipped; `.fixed(p)` uses `p`; `.sequence(points)` uses the point of tick `n`, `points[(n − 1) mod k]`,
/// 2. moves a fixed or sequence target by a random vector from the position offset disk (ADR-012); the current cursor
///    is never moved, so offsets cannot add up into a random walk,
/// 3. asks the failsafe what to do with the cursor and that final point (`nil` failsafe means always proceed),
/// 4. posts the click there with the run's click type and modifiers,
/// 5. increments the shared total `ClickCounter` and the run's own click count,
/// 6. checks the stop condition.
///
/// ## Schedule
/// The scheduler's step list (ADR-011) is the interval for `.currentCursor` and `.fixed`, and the points' delays for
/// `.sequence`, so the first point is clicked one delay after start. The configuration's jitter applies to every tick
/// either way. A sequence point follows its tick's index, so a tick skipped after a stall also skips its point and the
/// order stays aligned with the schedule.
///
/// ## Counting
/// The injected `ClickCounter` is the UI's total and is never reset here; only the user's Reset button does that.
/// `.afterClicks(n)` counts the clicks of the current run only, every sequence point included. Skipped ticks are not
/// counted anywhere.
///
/// ## Stop condition timing
/// `.afterDuration(t)` is measured from the run start with `ContinuousClock`: the scheduler delivers no tick due
/// after `t` and ends the run at `t`, even while every tick is being skipped. `.afterClicks(n)` stops right after the
/// n-th posted click. A condition that is already satisfied at start (a limit of zero or less) ends the run at once,
/// and so does an empty sequence, which has nothing to click.
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
    private let positionOffset: @Sendable (Int) -> CGVector
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
    ///   - positionOffset: Draws one click's offset from a disk of the given radius in points. The radius is always
    ///     inside `ClickConfiguration.positionOffsetRange` and above zero. Called on the click queue; inject a
    ///     deterministic function in tests.
    init(
        poster: any EventPosting,
        counter: ClickCounter,
        failsafe: (any FailsafeChecking)?,
        cursorLocation: @escaping @Sendable () -> CGPoint? = ScreenGeometry.currentCursorLocation,
        queue: DispatchQueue = DispatchQueue(label: "AutoClicker.ClickEngine", qos: .userInteractive),
        jitterOffset: @escaping @Sendable (ClickInterval) -> Duration = { $0.jitterOffset() },
        positionOffset: @escaping @Sendable (Int) -> CGVector = { PositionOffset.random(radius: $0) }
    ) {
        self.poster = poster
        self.counter = counter
        self.failsafe = failsafe
        self.cursorLocation = cursorLocation
        self.positionOffset = positionOffset
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
        let started: (runID: UInt64, isEmpty: Bool)? = state.withLock { state in
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
            // An empty sequence has no steps; its run ends below without ever starting the scheduler.
            guard let steps = Self.steps(for: configuration.target, interval: configuration.interval) else {
                return (runID, isEmpty: true)
            }
            // Started under the engine lock so a concurrent `stop` cannot slip in between and leave an orphaned
            // scheduler run behind. Lock order is always engine, then scheduler; the scheduler never calls back while
            // holding its own lock.
            scheduler.start(
                steps: steps,
                jitterMilliseconds: configuration.interval.jitterMilliseconds,
                limit: limit,
                onTick: { [weak self] tick in
                    self?.handleTick(tick, runID: runID)
                },
                onLimit: { [weak self] in
                    self?.stop(reason: .conditionMet, runID: runID)
                })
            return (runID, isEmpty: false)
        }
        guard let started else {
            return
        }
        // The view model never starts an empty sequence. If one gets here anyway, it ends like a condition that is
        // already met, so the run is still reported exactly once instead of hanging without ticks.
        if started.isEmpty || configuration.stopCondition.isSatisfied(clicks: 0, elapsed: .zero) {
            stop(reason: .conditionMet, runID: started.runID)
        }
    }

    /// Stops the active run and reports `reason` through `onStop`. Does nothing if no run is active, so `onStop` is
    /// never called twice for one run.
    func stop(reason: StopReason = .user) {
        stop(reason: reason, runID: nil)
    }

    /// Returns the point tick `index` (1-based) aims at before any offset, or `nil` if it has none.
    ///
    /// `.currentCursor` uses `cursor`, and `.sequence(points)` uses `points[(index − 1) mod k]`, so a skipped tick also
    /// skips its point. Internal rather than private so tests can check the mapping for any tick index.
    static func basePoint(for target: ClickTarget, tick index: Int, cursor: CGPoint?) -> CGPoint? {
        switch target {
        case .currentCursor:
            return cursor
        case .fixed(let point):
            return point
        case .sequence(let points):
            // An empty sequence never gets a tick, but must not crash if it somehow does.
            guard !points.isEmpty else {
                return nil
            }
            let count = points.count
            return points[((index - 1) % count + count) % count].point
        }
    }

    // MARK: - Private

    /// The scheduler steps of a run, or `nil` for an empty sequence.
    private static func steps(for target: ClickTarget, interval: ClickInterval) -> ClickScheduler.Steps? {
        switch target {
        case .currentCursor, .fixed:
            ClickScheduler.Steps(interval.duration)
        case .sequence(let points):
            ClickScheduler.Steps(points.map(\.delay))
        }
    }

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
        let target = Self.basePoint(for: configuration.target, tick: tick.index, cursor: cursor).map { point in
            offsetPoint(point, target: configuration.target, radius: configuration.positionOffset)
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

    /// Moves `point` by a fresh random offset, or returns it unchanged for `.currentCursor` or a radius of zero.
    private func offsetPoint(_ point: CGPoint, target: ClickTarget, radius: Int) -> CGPoint {
        // A posted click moves the pointer, so offsetting the cursor target would walk away from it click by click.
        if case .currentCursor = target {
            return point
        }
        let range = ClickConfiguration.positionOffsetRange
        let radius = min(max(radius, range.lowerBound), range.upperBound)
        guard radius > 0 else {
            return point
        }
        let offset = positionOffset(radius)
        return CGPoint(x: point.x + offset.dx, y: point.y + offset.dy)
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
