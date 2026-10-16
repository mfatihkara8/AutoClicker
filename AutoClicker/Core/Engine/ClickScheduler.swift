import Dispatch
import os

/// Fires ticks against absolute deadlines on a serial dispatch queue (ADR-005).
///
/// Tick `n` (counting from 1) is due at `start + n × interval.duration + jitterOffset(n)`, where `start` is a
/// `ContinuousClock` instant taken in `start(interval:limit:onTick:onLimit:)`. Every deadline is computed from `start`,
/// never from the previous tick, so neither handler time nor timer latency accumulates, and each jitter offset is drawn
/// per tick and never carried over (see `ClickInterval`). The first tick fires one interval after start, not
/// immediately.
///
/// ## Falling behind
/// The timer is one-shot and re-armed after each tick, so a late wakeup (a busy machine, a slow handler, system sleep)
/// fires exactly one tick. The scheduler then skips ahead to the first tick whose deadline is still in the future
/// instead of burst-firing the missed ones; their indices are simply never delivered, which `Tick.index` makes visible.
///
/// ## Limit
/// When a `limit` is given, no tick due after it is delivered. Instead, the scheduler stops itself at `start + limit`
/// and calls `onLimit`. A tick due exactly at the limit is still delivered first.
///
/// ## Threading
/// `start` and `stop` are idempotent and safe to call from any thread, including from inside a handler. Handlers run on
/// `queue` and never under the scheduler's lock. A handler already running when `stop()` returns finishes normally,
/// but no further handler of that run is called.
final class ClickScheduler: Sendable {
    /// One delivered tick.
    struct Tick: Sendable, Equatable {
        /// The 1-based tick number in the run. Skipped ticks leave gaps.
        let index: Int
        /// When the tick was due, measured from the run's start and including its jitter offset.
        let deadline: Duration
    }

    private struct Run {
        let generation: UInt64
        let timer: any DispatchSourceTimer
        let start: ContinuousClock.Instant
        let interval: ClickInterval
        let limit: Duration?
        let onTick: @Sendable (Tick) -> Void
        let onLimit: @Sendable () -> Void
        /// The tick the timer is armed for, or `nil` when it is armed for the limit.
        var pending: Tick?
    }

    private struct State {
        var generation: UInt64 = 0
        var run: Run?
    }

    private enum Event {
        case tick(Tick, @Sendable (Tick) -> Void)
        case limit(@Sendable () -> Void)
    }

    private let queue: DispatchQueue
    private let clock = ContinuousClock()
    private let jitterOffset: @Sendable (ClickInterval) -> Duration
    // `uncheckedState` because `DispatchSourceTimer` is not declared `Sendable`. The timer is only touched while the
    // lock is held, and dispatch sources are thread-safe to configure and cancel anyway.
    private let state = OSAllocatedUnfairLock(uncheckedState: State())

    /// Creates an idle scheduler.
    ///
    /// - Parameters:
    ///   - queue: The serial queue that runs the timer and every handler.
    ///   - jitterOffset: Returns the random offset for one tick. Inject a deterministic function in tests.
    init(
        queue: DispatchQueue,
        jitterOffset: @escaping @Sendable (ClickInterval) -> Duration = { $0.jitterOffset() }
    ) {
        self.queue = queue
        self.jitterOffset = jitterOffset
    }

    deinit {
        state.withLockUnchecked { $0.run?.timer.cancel() }
    }

    /// Whether a run is active.
    var isRunning: Bool {
        state.withLockUnchecked { $0.run != nil }
    }

    /// Starts a run. Does nothing if one is already active.
    ///
    /// - Parameters:
    ///   - interval: The tick interval and jitter. `interval.duration` is never shorter than 1 ms.
    ///   - limit: The run length after which no more ticks are delivered, or `nil` to run until `stop()`.
    ///   - onTick: Called on `queue` for every tick.
    ///   - onLimit: Called once on `queue` when `limit` is reached. The scheduler is already stopped by then.
    /// - Returns: Whether a new run was started.
    @discardableResult
    func start(
        interval: ClickInterval,
        limit: Duration? = nil,
        onTick: @escaping @Sendable (Tick) -> Void,
        onLimit: @escaping @Sendable () -> Void = {}
    ) -> Bool {
        state.withLockUnchecked { state in
            guard state.run == nil else {
                return false
            }
            state.generation &+= 1
            let generation = state.generation
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
            timer.setEventHandler { [weak self] in
                self?.fire(generation: generation)
            }
            var run = Run(
                generation: generation,
                timer: timer,
                start: clock.now,
                interval: interval,
                limit: limit,
                onTick: onTick,
                onLimit: onLimit,
                pending: nil)
            arm(&run, after: 0)
            state.run = run
            timer.resume()
            return true
        }
    }

    /// Stops the active run and cancels its timer. Does nothing if no run is active.
    func stop() {
        state.withLockUnchecked { state in
            state.run?.timer.cancel()
            state.run = nil
        }
    }

    // MARK: - Deadlines

    /// Returns the first tick after `lastIndex` whose deadline lies after `elapsed`.
    ///
    /// Ticks whose deadline has already passed are skipped rather than fired late. `offset` is called once per
    /// candidate tick to draw its jitter.
    static func nextTick(
        after lastIndex: Int,
        elapsed: Duration,
        interval: Duration,
        offset: () -> Duration
    ) -> Tick {
        // A non-positive interval would never move the deadline forward.
        let interval = max(interval, .nanoseconds(1))
        var index = lastIndex + 1
        // Jump straight to the neighborhood of `elapsed` so a long stall (e.g. system sleep) costs O(1), not one loop
        // iteration per missed tick. `elapsed / interval` is a finite, non-negative Double here.
        let behind = elapsed > .zero ? Int((elapsed / interval).rounded(.down)) : 0
        index = max(index, behind)
        while true {
            let deadline = interval * index + offset()
            if deadline > elapsed {
                return Tick(index: index, deadline: deadline)
            }
            index += 1
        }
    }

    // MARK: - Private

    private func fire(generation: UInt64) {
        let event = state.withLockUnchecked { state -> Event? in
            guard let run = state.run, run.generation == generation else {
                return nil
            }
            guard let tick = run.pending else {
                run.timer.cancel()
                state.run = nil
                return .limit(run.onLimit)
            }
            return .tick(tick, run.onTick)
        }

        switch event {
        case .tick(let tick, let onTick):
            onTick(tick)
            // Re-arm after the handler so the skip-ahead decision sees the time the handler actually took.
            state.withLockUnchecked { state in
                guard var run = state.run, run.generation == generation else {
                    return
                }
                arm(&run, after: tick.index)
                state.run = run
            }
        case .limit(let onLimit):
            onLimit()
        case nil:
            return
        }
    }

    /// Arms the run's timer for the next tick after `lastIndex`, or for the limit if that tick would be due after it.
    /// Must be called with the lock held.
    private func arm(_ run: inout Run, after lastIndex: Int) {
        let now = clock.now
        let elapsed = now - run.start
        let interval = run.interval
        let next = Self.nextTick(after: lastIndex, elapsed: elapsed, interval: interval.duration) {
            jitterOffset(interval)
        }
        let target: Duration
        if let limit = run.limit, next.deadline > limit {
            run.pending = nil
            target = limit
        } else {
            run.pending = next
            target = next.deadline
        }
        // The dispatch clock (uptime) and `ContinuousClock` differ across system sleep, so convert the absolute
        // deadline into a relative delay on every re-arm instead of keeping a dispatch deadline around. The conversion
        // error is microseconds and does not accumulate, because the next re-arm starts from `run.start` again.
        run.timer.schedule(
            deadline: .now() + Self.dispatchInterval(target - elapsed), repeating: .never, leeway: .nanoseconds(0))
    }

    private static func dispatchInterval(_ duration: Duration) -> DispatchTimeInterval {
        guard duration > .zero else {
            return .nanoseconds(0)
        }
        let (seconds, attoseconds) = duration.components
        // Beyond this the nanosecond count would overflow `Int`; such a delay (about 292 years) never fires anyway.
        guard seconds < Int64(Int.max / 1_000_000_000) else {
            return .never
        }
        return .nanoseconds(Int(seconds) * 1_000_000_000 + Int(attoseconds / 1_000_000_000))
    }
}
