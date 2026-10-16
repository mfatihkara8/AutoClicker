import Dispatch
import Testing
import os

@testable import AutoClicker

struct ClickSchedulerTests {
    private static func makeQueue() -> DispatchQueue {
        DispatchQueue(label: "ClickSchedulerTests", qos: .userInteractive)
    }

    // MARK: - Deadline math

    @Test func firstTickIsOneIntervalAfterStart() {
        let tick = ClickScheduler.nextTick(after: 0, elapsed: .zero, interval: .milliseconds(10)) { .zero }
        #expect(tick == ClickScheduler.Tick(index: 1, deadline: .milliseconds(10)))
    }

    @Test func nextTickFollowsLastOneWhenOnTime() {
        let tick = ClickScheduler.nextTick(after: 3, elapsed: .microseconds(30_500), interval: .milliseconds(10)) {
            .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 4, deadline: .milliseconds(40)))
    }

    @Test func missedTicksAreSkippedNotBurstFired() {
        // Tick 3 ran late, at 75 ms: ticks 4...7 are already overdue and must not fire.
        let tick = ClickScheduler.nextTick(after: 3, elapsed: .milliseconds(75), interval: .milliseconds(10)) { .zero }
        #expect(tick == ClickScheduler.Tick(index: 8, deadline: .milliseconds(80)))
    }

    @Test func deadlineEqualToNowCountsAsMissed() {
        let tick = ClickScheduler.nextTick(after: 3, elapsed: .milliseconds(40), interval: .milliseconds(10)) { .zero }
        #expect(tick.index == 5)
    }

    @Test func jitterIsAddedPerTickAndNotAccumulated() {
        let interval = Duration.milliseconds(10)
        let first = ClickScheduler.nextTick(after: 0, elapsed: .zero, interval: interval) { .milliseconds(3) }
        let second = ClickScheduler.nextTick(after: first.index, elapsed: first.deadline, interval: interval) {
            .milliseconds(3)
        }
        #expect(first.deadline == .milliseconds(13))
        // Anchored at 2 × 10 ms, not at the previous jittered deadline (which would give 26 ms).
        #expect(second.deadline == .milliseconds(23))
    }

    @Test func negativeJitterThatLandsInThePastSkipsThatTick() {
        let tick = ClickScheduler.nextTick(after: 3, elapsed: .milliseconds(39), interval: .milliseconds(10)) {
            .milliseconds(-2)
        }
        #expect(tick == ClickScheduler.Tick(index: 5, deadline: .milliseconds(48)))
    }

    @Test func longStallJumpsAheadWithoutIteratingEveryMissedTick() {
        var offsetCalls = 0
        let tick = ClickScheduler.nextTick(after: 1, elapsed: .seconds(3_600), interval: .milliseconds(1)) {
            offsetCalls += 1
            return .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 3_600_001, deadline: .milliseconds(3_600_001)))
        #expect(offsetCalls <= 3)
    }

    // MARK: - Timing

    /// SC-6 / T-204 "Done when": 1,000 ticks at 5 ms take 5 s within ±2 %.
    @Test func driftStaysWithinTwoPercentOverOneThousandTicks() async {
        let tickCount = 1_000
        let interval = ClickInterval(milliseconds: 5)
        let scheduler = ClickScheduler(queue: Self.makeQueue())
        let clock = ContinuousClock()
        let fired = CallRecorder<ClickScheduler.Tick>()
        let finished = OSAllocatedUnfairLock<Duration?>(initialState: nil)

        let start = clock.now
        scheduler.start(interval: interval) { tick in
            if fired.record(tick) == tickCount {
                let elapsed = clock.now - start
                finished.withLock { $0 = elapsed }
            }
        }
        let done = await waitUntil(timeout: .seconds(15)) { finished.withLock { $0 != nil } }
        scheduler.stop()

        #expect(done)
        guard let elapsed = finished.withLock({ $0 }) else {
            return
        }
        let expected = interval.duration * tickCount
        let drift = abs(elapsed / expected - 1)
        #expect(drift <= 0.02, "elapsed \(elapsed) for \(tickCount) ticks, expected \(expected)")
    }

    @Test func jitterDoesNotAccumulateIntoDrift() async {
        let tickCount = 400
        // 4 ms ± 1 ms; the offsets cycle through the extremes so a summing bug would show up immediately.
        let interval = ClickInterval(milliseconds: 4, jitterMilliseconds: 1)
        let offsets: [Duration] = [.milliseconds(1), .milliseconds(-1), .milliseconds(1)]
        let draws = OSAllocatedUnfairLock(initialState: 0)
        let scheduler = ClickScheduler(queue: Self.makeQueue()) { _ in
            draws.withLock { count in
                defer { count += 1 }
                return offsets[count % offsets.count]
            }
        }
        let clock = ContinuousClock()
        let fired = CallRecorder<ClickScheduler.Tick>()
        let finished = OSAllocatedUnfairLock<Duration?>(initialState: nil)

        let start = clock.now
        scheduler.start(interval: interval) { tick in
            if fired.record(tick) == tickCount {
                let elapsed = clock.now - start
                finished.withLock { $0 = elapsed }
            }
        }
        let done = await waitUntil(timeout: .seconds(10)) { finished.withLock { $0 != nil } }
        scheduler.stop()

        #expect(done)
        guard let elapsed = finished.withLock({ $0 }) else {
            return
        }
        let expected = interval.duration * tickCount
        #expect(abs(elapsed / expected - 1) <= 0.02, "elapsed \(elapsed), expected \(expected)")
        for tick in fired.values.prefix(tickCount) {
            let base = interval.duration * tick.index
            let offset = tick.deadline - base
            #expect(offset >= .milliseconds(-1) && offset <= .milliseconds(1))
        }
    }

    // MARK: - Lifecycle

    @Test func ticksAreDeliveredOnTheSchedulerQueue() async {
        let queue = Self.makeQueue()
        let key = DispatchSpecificKey<Bool>()
        queue.setSpecific(key: key, value: true)
        let scheduler = ClickScheduler(queue: queue)
        let onQueue = CallRecorder<Bool>()

        scheduler.start(interval: ClickInterval(milliseconds: 1)) { _ in
            onQueue.record(DispatchQueue.getSpecific(key: key) == true)
        }
        #expect(await waitUntil { onQueue.count >= 3 })
        scheduler.stop()

        #expect(onQueue.values.allSatisfy { $0 })
    }

    @Test func startIsIdempotent() async {
        let queue = Self.makeQueue()
        let scheduler = ClickScheduler(queue: queue)
        let first = CallRecorder<Int>()
        let second = CallRecorder<Int>()

        #expect(scheduler.start(interval: ClickInterval(milliseconds: 1)) { first.record($0.index) })
        #expect(!scheduler.start(interval: ClickInterval(milliseconds: 1)) { second.record($0.index) })
        #expect(await waitUntil { first.count >= 3 })
        scheduler.stop()
        await drain(queue)

        #expect(second.count == 0)
        // Indices strictly increase: one run, never restarted by the second call.
        let indices = first.values
        #expect(zip(indices, indices.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func stopIsIdempotentAndEndsTicks() async throws {
        let queue = Self.makeQueue()
        let scheduler = ClickScheduler(queue: queue)
        let fired = CallRecorder<Int>()

        scheduler.stop()
        scheduler.start(interval: ClickInterval(milliseconds: 1)) { fired.record($0.index) }
        #expect(scheduler.isRunning)
        #expect(await waitUntil { fired.count >= 3 })
        scheduler.stop()
        scheduler.stop()
        await drain(queue)
        let countAfterStop = fired.count

        try await Task.sleep(for: .milliseconds(20))
        #expect(!scheduler.isRunning)
        #expect(fired.count == countAfterStop)
    }

    @Test func stopFromInsideTheHandlerEndsTheRun() async throws {
        let queue = Self.makeQueue()
        let scheduler = ClickScheduler(queue: queue)
        let fired = CallRecorder<Int>()

        scheduler.start(interval: ClickInterval(milliseconds: 1)) { [weak scheduler] tick in
            if fired.record(tick.index) == 3 {
                scheduler?.stop()
            }
        }
        #expect(await waitUntil { fired.count >= 3 })
        try await Task.sleep(for: .milliseconds(20))

        #expect(fired.count == 3)
        #expect(!scheduler.isRunning)
    }

    @Test func canRestartAfterStop() async {
        let queue = Self.makeQueue()
        let scheduler = ClickScheduler(queue: queue)
        let fired = CallRecorder<Int>()

        scheduler.start(interval: ClickInterval(milliseconds: 1)) { fired.record($0.index) }
        #expect(await waitUntil { fired.count >= 2 })
        scheduler.stop()
        await drain(queue)
        let firstRunCount = fired.count

        scheduler.start(interval: ClickInterval(milliseconds: 1)) { fired.record($0.index) }
        #expect(await waitUntil { fired.count >= firstRunCount + 2 })
        scheduler.stop()

        // The second run counts from tick 1 again.
        #expect(fired.values.dropFirst(firstRunCount).first == 1)
    }

    @Test func limitDeliversTicksUpToAndIncludingItThenStops() async {
        let queue = Self.makeQueue()
        let scheduler = ClickScheduler(queue: queue)
        let fired = CallRecorder<ClickScheduler.Tick>()
        let limits = CallRecorder<Bool>()

        // Ticks are due at 20, 40 and 60 ms; the one due exactly at the limit is still delivered.
        scheduler.start(
            interval: ClickInterval(milliseconds: 20),
            limit: .milliseconds(60),
            onTick: { fired.record($0) },
            onLimit: { limits.record(true) })
        #expect(await waitUntil { limits.count == 1 })
        await drain(queue)

        #expect(!scheduler.isRunning)
        #expect(limits.count == 1)
        #expect(fired.values.allSatisfy { $0.deadline <= .milliseconds(60) })
        #expect(fired.values.last?.index == 3)
    }

    @Test func limitShorterThanTheIntervalStopsBeforeAnyTick() async {
        let queue = Self.makeQueue()
        let scheduler = ClickScheduler(queue: queue)
        let fired = CallRecorder<Int>()
        let limits = CallRecorder<ContinuousClock.Instant>()
        let clock = ContinuousClock()
        let start = clock.now

        scheduler.start(
            interval: ClickInterval(seconds: 10),
            limit: .milliseconds(10),
            onTick: { fired.record($0.index) },
            onLimit: { limits.record(clock.now) })
        #expect(await waitUntil { limits.count == 1 })

        #expect(fired.count == 0)
        if let stoppedAt = limits.values.first {
            // Ends at the limit, not at the first (10 s) tick.
            #expect(stoppedAt - start < .seconds(1))
        }
    }

    @Test func zeroLimitStopsImmediately() async {
        let scheduler = ClickScheduler(queue: Self.makeQueue())
        let fired = CallRecorder<Int>()
        let limits = CallRecorder<Bool>()

        scheduler.start(
            interval: ClickInterval(milliseconds: 1),
            limit: .zero,
            onTick: { fired.record($0.index) },
            onLimit: { limits.record(true) })
        #expect(await waitUntil { limits.count == 1 })

        #expect(fired.count == 0)
        #expect(!scheduler.isRunning)
    }

    @Test func deinitCancelsTheTimer() async throws {
        let queue = Self.makeQueue()
        let fired = CallRecorder<Int>()
        weak var weakScheduler: ClickScheduler?
        do {
            let scheduler = ClickScheduler(queue: queue)
            weakScheduler = scheduler
            scheduler.start(interval: ClickInterval(milliseconds: 1)) { fired.record($0.index) }
            #expect(await waitUntil { fired.count >= 2 })
        }
        await drain(queue)
        let countAfterRelease = fired.count

        try await Task.sleep(for: .milliseconds(20))
        #expect(weakScheduler == nil)
        #expect(fired.count == countAfterRelease)
    }
}
