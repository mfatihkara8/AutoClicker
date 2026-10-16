import CoreGraphics
import Dispatch
import Testing
import os

@testable import AutoClicker

struct ClickEngineTests {
    /// One engine plus every test double wired into it.
    private struct Harness {
        let engine: ClickEngine
        let poster = MockEventPoster()
        let counter: ClickCounter
        let failsafe: MockFailsafe?
        let cursor: OSAllocatedUnfairLock<CGPoint?>
        let queue: DispatchQueue
        let stops = CallRecorder<StopReason>()

        init(
            counter: ClickCounter = ClickCounter(),
            failsafe: MockFailsafe? = MockFailsafe(),
            cursor: CGPoint? = CGPoint(x: 500, y: 400)
        ) {
            let queue = DispatchQueue(label: "ClickEngineTests", qos: .userInteractive)
            let cursorBox = OSAllocatedUnfairLock<CGPoint?>(initialState: cursor)
            self.counter = counter
            self.failsafe = failsafe
            self.cursor = cursorBox
            self.queue = queue
            engine = ClickEngine(
                poster: poster,
                counter: counter,
                failsafe: failsafe,
                cursorLocation: { cursorBox.withLock { $0 } },
                queue: queue)
            let stops = stops
            engine.onStop = { stops.record($0) }
        }

        /// Waits for the first `onStop` and for any callback queued behind it.
        func waitForStop() async -> Bool {
            let stops = stops
            let stopped = await waitUntil { stops.count >= 1 }
            await drain(queue)
            return stopped
        }
    }

    private static func configuration(
        _ clickType: ClickType = .left,
        milliseconds: Int = 1,
        target: ClickTarget = .fixed(CGPoint(x: 10, y: 20)),
        stopCondition: StopCondition = .never
    ) -> ClickConfiguration {
        ClickConfiguration(
            clickType: clickType,
            interval: ClickInterval(milliseconds: milliseconds),
            target: target,
            stopCondition: stopCondition)
    }

    // MARK: - Click types and targets

    @Test(arguments: ClickType.allCases)
    func postsTheConfiguredClickType(_ clickType: ClickType) async {
        let harness = Harness()
        let point = CGPoint(x: 10, y: 20)

        harness.engine.start(Self.configuration(clickType, target: .fixed(point), stopCondition: .afterClicks(3)))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts == Array(repeating: MockEventPoster.Post(type: clickType, point: point), count: 3))
    }

    @Test func currentCursorTargetClicksWhereTheCursorIs() async {
        let first = CGPoint(x: 100, y: 200)
        let second = CGPoint(x: 300, y: 50)
        let harness = Harness(cursor: first)
        let poster = harness.poster

        harness.engine.start(Self.configuration(target: .currentCursor))
        #expect(await waitUntil { poster.count >= 2 })
        harness.cursor.withLock { $0 = second }
        let countBeforeMove = poster.count
        #expect(await waitUntil { poster.count >= countBeforeMove + 2 })
        harness.engine.stop()
        await drain(harness.queue)

        let points = poster.posts.map(\.point)
        #expect(points.first == first)
        #expect(points.last == second)
        #expect(points.allSatisfy { $0 == first || $0 == second })
    }

    @Test func fixedTargetIgnoresTheCursorButStillReportsItToTheFailsafe() async {
        let cursor = CGPoint(x: 700, y: 300)
        let fixed = CGPoint(x: 42, y: 84)
        let harness = Harness(cursor: cursor)

        harness.engine.start(Self.configuration(target: .fixed(fixed), stopCondition: .afterClicks(2)))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts.map(\.point) == [fixed, fixed])
        #expect(
            harness.failsafe?.evaluations
                == Array(repeating: MockFailsafe.Evaluation(cursor: cursor, target: fixed), count: 2))
    }

    @Test func unreadableCursorSkipsTicksWithoutCounting() async {
        let harness = Harness(cursor: nil)

        harness.engine.start(
            Self.configuration(target: .currentCursor, stopCondition: .afterDuration(.milliseconds(20))))
        #expect(await harness.waitForStop())

        #expect(harness.poster.count == 0)
        #expect(harness.counter.value == 0)
        #expect(harness.failsafe?.evaluations.isEmpty == true)
        #expect(harness.stops.values == [.conditionMet])
    }

    @Test func worksWithoutAFailsafe() async {
        let harness = Harness(failsafe: nil)

        harness.engine.start(Self.configuration(target: .currentCursor, stopCondition: .afterClicks(2)))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts.map(\.point) == [CGPoint(x: 500, y: 400), CGPoint(x: 500, y: 400)])
    }

    // MARK: - Stop conditions

    @Test func afterClicksStopsAtExactlyNClicks() async throws {
        let harness = Harness()

        harness.engine.start(Self.configuration(stopCondition: .afterClicks(5)))
        #expect(await harness.waitForStop())
        try await Task.sleep(for: .milliseconds(10))
        await drain(harness.queue)

        #expect(harness.poster.count == 5)
        #expect(harness.counter.value == 5)
        #expect(harness.stops.values == [.conditionMet])
        #expect(!harness.engine.isRunning)
    }

    @Test func afterDurationStopsWhenTheTimeIsUp() async {
        let harness = Harness()
        let clock = ContinuousClock()
        let start = clock.now

        // Ticks are due at 10, 20, ... ms, so at most 5 fit into 55 ms.
        harness.engine.start(Self.configuration(milliseconds: 10, stopCondition: .afterDuration(.milliseconds(55))))
        #expect(await harness.waitForStop())
        let elapsed = clock.now - start

        #expect(harness.stops.values == [.conditionMet])
        #expect((1...5).contains(harness.poster.count))
        #expect(harness.counter.value == harness.poster.count)
        #expect(elapsed >= .milliseconds(55))
    }

    @Test func afterDurationStopsEvenWhileEveryTickIsSkipped() async {
        let harness = Harness(failsafe: MockFailsafe(decision: .skipInsideOwnWindow))

        harness.engine.start(Self.configuration(stopCondition: .afterDuration(.milliseconds(20))))
        #expect(await harness.waitForStop())

        #expect(harness.stops.values == [.conditionMet])
        #expect(harness.poster.count == 0)
        #expect(harness.counter.value == 0)
    }

    @Test(arguments: [StopCondition.afterClicks(0), .afterDuration(.zero)])
    func alreadySatisfiedConditionEndsTheRunAtOnce(_ condition: StopCondition) async {
        let harness = Harness()

        harness.engine.start(Self.configuration(milliseconds: 50, stopCondition: condition))
        #expect(await harness.waitForStop())

        #expect(harness.stops.values == [.conditionMet])
        #expect(harness.poster.count == 0)
    }

    // MARK: - Failsafes

    @Test func cornerFailsafeStopsTheRun() async {
        let failsafe = MockFailsafe()
        let harness = Harness(failsafe: failsafe)
        let poster = harness.poster

        harness.engine.start(Self.configuration())
        #expect(await waitUntil { poster.count >= 3 })
        failsafe.decision = .stopCornerReached
        #expect(await harness.waitForStop())
        let postsAtStop = poster.count
        await drain(harness.queue)

        #expect(harness.stops.values == [.cornerFailsafe])
        #expect(!harness.engine.isRunning)
        #expect(poster.count == postsAtStop)
        #expect(harness.counter.value == postsAtStop)
    }

    @Test func cornerOnTheFirstTickPostsNothing() async {
        let harness = Harness(failsafe: MockFailsafe(decision: .stopCornerReached))

        harness.engine.start(Self.configuration())
        #expect(await harness.waitForStop())

        #expect(harness.stops.values == [.cornerFailsafe])
        #expect(harness.poster.count == 0)
    }

    @Test func ownWindowSkipsWithoutCountingAndResumesAutomatically() async {
        let failsafe = MockFailsafe(decision: .skipInsideOwnWindow)
        let harness = Harness(failsafe: failsafe)
        let engine = harness.engine
        let poster = harness.poster

        engine.start(Self.configuration(stopCondition: .afterClicks(3)))
        #expect(await waitUntil { failsafe.evaluations.count >= 5 })

        #expect(engine.isSkippingInsideOwnWindow)
        #expect(engine.isRunning)
        #expect(poster.count == 0)
        #expect(harness.counter.value == 0)

        failsafe.decision = .proceed
        #expect(await harness.waitForStop())

        // Skipped ticks did not count towards `.afterClicks(3)`.
        #expect(poster.count == 3)
        #expect(harness.counter.value == 3)
        #expect(!engine.isSkippingInsideOwnWindow)
        #expect(harness.stops.values == [.conditionMet])
    }

    @Test func skipFlagClearsAsSoonAsAClickIsPosted() async {
        let failsafe = MockFailsafe(decision: .skipInsideOwnWindow)
        let harness = Harness(failsafe: failsafe)
        let engine = harness.engine
        let poster = harness.poster

        engine.start(Self.configuration())
        #expect(await waitUntil { engine.isSkippingInsideOwnWindow })
        failsafe.decision = .proceed
        #expect(await waitUntil { poster.count >= 1 })
        #expect(await waitUntil { !engine.isSkippingInsideOwnWindow })
        engine.stop()

        #expect(!engine.isSkippingInsideOwnWindow)
    }

    // MARK: - Counter

    @Test func startDoesNotResetTheTotalCounter() async {
        let counter = ClickCounter()
        for _ in 0..<7 {
            counter.increment()
        }
        let harness = Harness(counter: counter)

        harness.engine.start(Self.configuration(stopCondition: .afterClicks(3)))
        #expect(await harness.waitForStop())
        #expect(counter.value == 10)

        // The per-run count starts over, the total keeps growing.
        harness.engine.start(Self.configuration(stopCondition: .afterClicks(3)))
        #expect(await waitUntil { harness.stops.count == 2 })
        await drain(harness.queue)
        #expect(counter.value == 13)
        #expect(harness.poster.count == 6)
    }

    // MARK: - Lifecycle

    @Test func startIsIdempotentAndKeepsTheFirstConfiguration() async {
        let harness = Harness()
        let first = CGPoint(x: 1, y: 1)

        harness.engine.start(Self.configuration(target: .fixed(first), stopCondition: .afterClicks(2)))
        harness.engine.start(
            Self.configuration(.right, target: .fixed(CGPoint(x: 9, y: 9)), stopCondition: .afterClicks(100)))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts == Array(repeating: MockEventPoster.Post(type: .left, point: first), count: 2))
        #expect(harness.stops.values == [.conditionMet])
    }

    @Test func stopIsIdempotentAndReportsOnce() async {
        let harness = Harness()

        harness.engine.start(Self.configuration())
        #expect(harness.engine.isRunning)
        harness.engine.stop()
        harness.engine.stop(reason: .hotkey)
        #expect(await harness.waitForStop())

        #expect(harness.stops.values == [.user])
        #expect(!harness.engine.isRunning)
    }

    @Test(arguments: [
        StopReason.user, .hotkey, .emergencyEscape, .cornerFailsafe, .conditionMet, .permissionLost,
    ])
    func stopDeliversTheGivenReason(_ reason: StopReason) async {
        let harness = Harness()

        harness.engine.start(Self.configuration())
        harness.engine.stop(reason: reason)
        #expect(await harness.waitForStop())

        #expect(harness.stops.values == [reason])
    }

    @Test func stopWithoutARunNeverCallsOnStop() async {
        let harness = Harness()

        harness.engine.stop()
        harness.engine.stop(reason: .permissionLost)
        await drain(harness.queue)

        #expect(harness.stops.count == 0)
    }

    @Test func stopAfterTheRunEndedDoesNotReportAgain() async {
        let harness = Harness()

        harness.engine.start(Self.configuration(stopCondition: .afterClicks(1)))
        #expect(await harness.waitForStop())
        harness.engine.stop(reason: .hotkey)
        await drain(harness.queue)

        #expect(harness.stops.values == [.conditionMet])
    }

    @Test func noClicksAfterStop() async throws {
        let harness = Harness()
        let poster = harness.poster

        harness.engine.start(Self.configuration())
        #expect(await waitUntil { poster.count >= 2 })
        harness.engine.stop()
        await drain(harness.queue)
        let countAfterStop = poster.count
        try await Task.sleep(for: .milliseconds(20))

        #expect(poster.count == countAfterStop)
    }

    @Test func onStopRunsOnTheClickQueue() async {
        let queue = DispatchQueue(label: "ClickEngineTests.onStop")
        let key = DispatchSpecificKey<Bool>()
        queue.setSpecific(key: key, value: true)
        let engine = ClickEngine(
            poster: MockEventPoster(), counter: ClickCounter(), failsafe: nil, cursorLocation: { nil }, queue: queue)
        let onQueue = CallRecorder<Bool>()
        engine.onStop = { _ in onQueue.record(DispatchQueue.getSpecific(key: key) == true) }

        engine.start(Self.configuration())
        engine.stop()
        #expect(await waitUntil { onQueue.count == 1 })

        #expect(onQueue.values == [true])
    }

    @Test func canStartAgainAfterStopping() async {
        let harness = Harness()

        harness.engine.start(Self.configuration(stopCondition: .afterClicks(1)))
        #expect(await harness.waitForStop())
        harness.engine.start(Self.configuration(.double, stopCondition: .afterClicks(1)))
        #expect(await waitUntil { harness.stops.count == 2 })

        #expect(harness.poster.posts.map(\.type) == [.left, .double])
        #expect(harness.stops.values == [.conditionMet, .conditionMet])
    }
}
