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
        let tick = ClickScheduler.nextTick(after: 0, elapsed: .zero, steps: ClickScheduler.Steps(.milliseconds(10))) {
            .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 1, deadline: .milliseconds(10)))
    }

    @Test func nextTickFollowsLastOneWhenOnTime() {
        let tick = ClickScheduler.nextTick(
            after: 3, elapsed: .microseconds(30_500), steps: ClickScheduler.Steps(.milliseconds(10))
        ) {
            .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 4, deadline: .milliseconds(40)))
    }

    @Test func missedTicksAreSkippedNotBurstFired() {
        // Tick 3 ran late, at 75 ms: ticks 4...7 are already overdue and must not fire.
        let tick = ClickScheduler.nextTick(
            after: 3, elapsed: .milliseconds(75), steps: ClickScheduler.Steps(.milliseconds(10))
        ) { .zero }
        #expect(tick == ClickScheduler.Tick(index: 8, deadline: .milliseconds(80)))
    }

    @Test func deadlineEqualToNowCountsAsMissed() {
        let tick = ClickScheduler.nextTick(
            after: 3, elapsed: .milliseconds(40), steps: ClickScheduler.Steps(.milliseconds(10))
        ) { .zero }
        #expect(tick.index == 5)
    }

    @Test func jitterIsAddedPerTickAndNotAccumulated() {
        let steps = ClickScheduler.Steps(.milliseconds(10))
        let first = ClickScheduler.nextTick(after: 0, elapsed: .zero, steps: steps) { .milliseconds(3) }
        let second = ClickScheduler.nextTick(after: first.index, elapsed: first.deadline, steps: steps) {
            .milliseconds(3)
        }
        #expect(first.deadline == .milliseconds(13))
        // Anchored at 2 × 10 ms, not at the previous jittered deadline (which would give 26 ms).
        #expect(second.deadline == .milliseconds(23))
    }

    @Test func negativeJitterThatLandsInThePastSkipsThatTick() {
        let tick = ClickScheduler.nextTick(
            after: 3, elapsed: .milliseconds(39), steps: ClickScheduler.Steps(.milliseconds(10))
        ) {
            .milliseconds(-2)
        }
        #expect(tick == ClickScheduler.Tick(index: 5, deadline: .milliseconds(48)))
    }

    @Test func longStallJumpsAheadWithoutIteratingEveryMissedTick() {
        var offsetCalls = 0
        let tick = ClickScheduler.nextTick(
            after: 1, elapsed: .seconds(3_600), steps: ClickScheduler.Steps(.milliseconds(1))
        ) {
            offsetCalls += 1
            return .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 3_600_001, deadline: .milliseconds(3_600_001)))
        #expect(offsetCalls <= 3)
    }

    // MARK: - Cyclic steps

    /// 200, 400 and 600 ms: a 1.2 s cycle.
    private static let threeSteps = ClickScheduler.Steps([
        .milliseconds(200), .milliseconds(400), .milliseconds(600),
    ])!

    @Test func emptyStepListIsRejected() {
        #expect(ClickScheduler.Steps([]) == nil)
    }

    @Test func stepsShorterThanOneMillisecondAreRaised() throws {
        let steps = try #require(ClickScheduler.Steps([.zero, .microseconds(10), .milliseconds(-5), .milliseconds(3)]))
        #expect(steps.durations == [.milliseconds(1), .milliseconds(1), .milliseconds(1), .milliseconds(3)])
        #expect(ClickScheduler.Steps(.zero).durations == [.milliseconds(1)])
        #expect(ClickScheduler.Steps(.zero).cycle == .milliseconds(1))
    }

    @Test func oneStepListMatchesTheSingleIntervalFormula() {
        let steps = ClickScheduler.Steps(.milliseconds(7))
        for index in 0...50 {
            #expect(steps.deadline(ofTick: index) == .milliseconds(7 * index))
        }
        #expect(steps.cycle == .milliseconds(7))
    }

    @Test func deadlinesAreTheCyclicSumOfTheSteps() {
        let steps = Self.threeSteps
        // 200, 200+400, 200+400+600, then the list starts over.
        let expected = [0, 200, 600, 1_200, 1_400, 1_800, 2_400, 2_600, 3_000, 3_600]
        for (index, milliseconds) in expected.enumerated() {
            #expect(steps.deadline(ofTick: index) == .milliseconds(milliseconds), "tick \(index)")
        }
        #expect(steps.cycle == .milliseconds(1_200))
    }

    @Test func lastTickNotAfterFindsTheTickAtOrBeforeElapsed() {
        let steps = Self.threeSteps
        #expect(steps.lastTick(notAfter: .zero) == 0)
        #expect(steps.lastTick(notAfter: .milliseconds(-5)) == 0)
        #expect(steps.lastTick(notAfter: .milliseconds(199)) == 0)
        #expect(steps.lastTick(notAfter: .milliseconds(200)) == 1)
        #expect(steps.lastTick(notAfter: .milliseconds(599)) == 1)
        #expect(steps.lastTick(notAfter: .milliseconds(600)) == 2)
        #expect(steps.lastTick(notAfter: .milliseconds(1_199)) == 2)
        #expect(steps.lastTick(notAfter: .milliseconds(1_200)) == 3)
        #expect(steps.lastTick(notAfter: .milliseconds(1_399)) == 3)
        #expect(steps.lastTick(notAfter: .milliseconds(1_400)) == 4)
        #expect(steps.lastTick(notAfter: .milliseconds(2_399)) == 5)
    }

    @Test func lastTickNotAfterAgreesWithABruteForceSearch() throws {
        let steps = try #require(
            ClickScheduler.Steps([.milliseconds(3), .milliseconds(1), .milliseconds(7), .milliseconds(2)]))
        var index = 0
        for elapsed in 0...200 {
            while steps.deadline(ofTick: index + 1) <= .milliseconds(elapsed) {
                index += 1
            }
            #expect(steps.lastTick(notAfter: .milliseconds(elapsed)) == index, "elapsed \(elapsed) ms")
        }
    }

    @Test func sequenceTicksFollowTheCyclicSchedule() {
        let steps = Self.threeSteps
        var tick = ClickScheduler.nextTick(after: 0, elapsed: .zero, steps: steps) { .zero }
        var deadlines = [tick.deadline]
        for _ in 0..<6 {
            tick = ClickScheduler.nextTick(after: tick.index, elapsed: tick.deadline, steps: steps) { .zero }
            deadlines.append(tick.deadline)
        }
        #expect(tick.index == 7)
        #expect(deadlines == [200, 600, 1_200, 1_400, 1_800, 2_400, 2_600].map { Duration.milliseconds($0) })
    }

    @Test func sequenceSkipAheadLandsOnTheRightStepInsideACycle() {
        // Tick 1 (due at 200 ms) ran late, at 1,500 ms: ticks 2...4 are overdue, tick 5 is due at 1,800 ms.
        let tick = ClickScheduler.nextTick(after: 1, elapsed: .milliseconds(1_500), steps: Self.threeSteps) {
            .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 5, deadline: .milliseconds(1_800)))
    }

    @Test func sequenceDeadlineEqualToNowCountsAsMissed() {
        let tick = ClickScheduler.nextTick(after: 2, elapsed: .milliseconds(1_200), steps: Self.threeSteps) {
            .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 4, deadline: .milliseconds(1_400)))
    }

    @Test func sequenceLongStallJumpsWholeCyclesInConstantTime() {
        var offsetCalls = 0
        // One hour is exactly 3,000 cycles of 1.2 s, so tick 9,000 is due right now and tick 9,001 is next.
        let tick = ClickScheduler.nextTick(after: 1, elapsed: .seconds(3_600), steps: Self.threeSteps) {
            offsetCalls += 1
            return .zero
        }
        #expect(tick == ClickScheduler.Tick(index: 9_001, deadline: .milliseconds(3_600_200)))
        #expect(offsetCalls <= 3)
    }

    @Test func sequenceLongStallOverManyCyclesOfFiftySteps() throws {
        // 50 steps of 1...50 ms: a cycle of 1,275 ms. A day later the search must still be immediate.
        let steps = try #require(ClickScheduler.Steps((1...50).map { Duration.milliseconds($0) }))
        var offsetCalls = 0
        let elapsed = Duration.seconds(86_400) + .milliseconds(7)
        let tick = ClickScheduler.nextTick(after: 3, elapsed: elapsed, steps: steps) {
            offsetCalls += 1
            return .zero
        }
        #expect(tick.deadline > elapsed)
        #expect(steps.deadline(ofTick: tick.index - 1) <= elapsed)
        #expect(offsetCalls <= 3)
    }

    @Test func sequenceJitterIsDrawnPerTickAndNotAccumulated() {
        let steps = Self.threeSteps
        let offsets: [Duration] = [.milliseconds(30), .milliseconds(-50), .milliseconds(10)]
        var draws = 0
        var tick = ClickScheduler.nextTick(after: 0, elapsed: .zero, steps: steps) {
            defer { draws += 1 }
            return offsets[draws % offsets.count]
        }
        var deadlines = [tick.deadline]
        for _ in 0..<2 {
            tick = ClickScheduler.nextTick(after: tick.index, elapsed: tick.deadline, steps: steps) {
                defer { draws += 1 }
                return offsets[draws % offsets.count]
            }
            deadlines.append(tick.deadline)
        }
        // Each offset lands on its own tick's cyclic base deadline (200, 600, 1,200 ms), never on the previous one.
        #expect(deadlines == [230, 550, 1_210].map { Duration.milliseconds($0) })
        #expect(draws == 3)
    }

    @Test func shortestMillisecondsRoundsDown() throws {
        let steps = try #require(ClickScheduler.Steps([.milliseconds(400), .microseconds(2_900), .seconds(1)]))
        #expect(steps.shortestMilliseconds == 2)
        #expect(Self.threeSteps.shortestMilliseconds == 200)
        #expect(ClickScheduler.Steps(.milliseconds(Int.max)).shortestMilliseconds == Int.max)
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
        scheduler.start(steps: ClickScheduler.Steps(interval.duration), jitterMilliseconds: interval.jitterMilliseconds)
        { tick in
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
        scheduler.start(steps: ClickScheduler.Steps(interval.duration), jitterMilliseconds: interval.jitterMilliseconds)
        { tick in
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

    @Test func sequenceRunDeliversTicksOnTheCyclicSchedule() async {
        let steps = ClickScheduler.Steps([.milliseconds(2), .milliseconds(4), .milliseconds(6)])!
        let scheduler = ClickScheduler(queue: Self.makeQueue())
        let fired = CallRecorder<ClickScheduler.Tick>()

        scheduler.start(steps: steps) { fired.record($0) }
        #expect(await waitUntil { fired.count >= 9 })
        scheduler.stop()

        for tick in fired.values {
            #expect(tick.deadline == steps.deadline(ofTick: tick.index))
        }
        let indices = fired.values.map(\.index)
        #expect(zip(indices, indices.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func sequenceJitterIsCappedByTheShortestStep() async {
        // The shortest step is 5 ms, so ±50 ms of requested jitter is capped at ±2 ms.
        let steps = ClickScheduler.Steps([.milliseconds(5), .milliseconds(40)])!
        let seen = CallRecorder<ClickInterval>()
        let scheduler = ClickScheduler(queue: Self.makeQueue()) { jitter in
            seen.record(jitter)
            return jitter.jitterOffset()
        }
        let fired = CallRecorder<ClickScheduler.Tick>()

        scheduler.start(steps: steps, jitterMilliseconds: 50) { fired.record($0) }
        #expect(await waitUntil { fired.count >= 4 })
        scheduler.stop()

        #expect(seen.values.allSatisfy { $0.effectiveJitterMilliseconds == 2 })
        for tick in fired.values {
            let offset = tick.deadline - steps.deadline(ofTick: tick.index)
            #expect(offset >= .milliseconds(-2) && offset <= .milliseconds(2))
        }
    }

    @Test func oneStepJitterKeepsTheIntervalsOwnCap() async {
        let interval = ClickInterval(milliseconds: 9, jitterMilliseconds: 3)
        let seen = CallRecorder<Int>()
        let scheduler = ClickScheduler(queue: Self.makeQueue()) { jitter in
            seen.record(jitter.effectiveJitterMilliseconds)
            return .zero
        }

        scheduler.start(
            steps: ClickScheduler.Steps(interval.duration),
            jitterMilliseconds: interval.jitterMilliseconds,
            onTick: { _ in })
        #expect(await waitUntil { seen.count >= 2 })
        scheduler.stop()

        #expect(seen.values.allSatisfy { $0 == interval.effectiveJitterMilliseconds })
    }

    // MARK: - Lifecycle

    @Test func ticksAreDeliveredOnTheSchedulerQueue() async {
        let queue = Self.makeQueue()
        let key = DispatchSpecificKey<Bool>()
        queue.setSpecific(key: key, value: true)
        let scheduler = ClickScheduler(queue: queue)
        let onQueue = CallRecorder<Bool>()

        scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { _ in
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

        #expect(scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { first.record($0.index) })
        #expect(!scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { second.record($0.index) })
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
        scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { fired.record($0.index) }
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

        scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { [weak scheduler] tick in
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

        scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { fired.record($0.index) }
        #expect(await waitUntil { fired.count >= 2 })
        scheduler.stop()
        await drain(queue)
        let firstRunCount = fired.count

        scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { fired.record($0.index) }
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
            steps: ClickScheduler.Steps(.milliseconds(20)),
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
            steps: ClickScheduler.Steps(.seconds(10)),
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
            steps: ClickScheduler.Steps(.milliseconds(1)),
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
            scheduler.start(steps: ClickScheduler.Steps(.milliseconds(1))) { fired.record($0.index) }
            #expect(await waitUntil { fired.count >= 2 })
        }
        await drain(queue)
        let countAfterRelease = fired.count

        try await Task.sleep(for: .milliseconds(20))
        #expect(weakScheduler == nil)
        #expect(fired.count == countAfterRelease)
    }
}
