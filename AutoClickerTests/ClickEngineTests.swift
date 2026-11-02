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
            cursor: CGPoint? = CGPoint(x: 500, y: 400),
            jitterOffset: @escaping @Sendable (ClickInterval) -> Duration = { $0.jitterOffset() },
            positionOffset: @escaping @Sendable (Int) -> CGVector = { PositionOffset.random(radius: $0) }
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
                queue: queue,
                jitterOffset: jitterOffset,
                positionOffset: positionOffset)
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
        stopCondition: StopCondition = .never,
        modifiers: ClickModifiers = [],
        positionOffset: Int = 0
    ) -> ClickConfiguration {
        ClickConfiguration(
            clickType: clickType,
            interval: ClickInterval(milliseconds: milliseconds),
            target: target,
            stopCondition: stopCondition,
            modifiers: modifiers,
            positionOffset: positionOffset)
    }

    private static let sequencePoints = [
        CGPoint(x: 10, y: 10), CGPoint(x: 200, y: 20), CGPoint(x: 30, y: 300),
    ]

    /// A sequence of `sequencePoints`, each `delay` milliseconds apart. The delays are long enough that a busy test
    /// machine does not skip a tick, which would also skip its point.
    private static func sequence(delay: Int = 15) -> ClickTarget {
        .sequence(sequencePoints.map { ClickPoint(point: $0, delayMilliseconds: delay) })
    }

    /// The fixed offset every stubbed draw returns.
    private static let stubOffset = CGVector(dx: 3, dy: -4)

    private static func offset(_ point: CGPoint, by vector: CGVector = stubOffset) -> CGPoint {
        CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
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

    @Test(arguments: ClickType.allCases)
    func passesTheConfiguredModifiersOnEveryClick(_ clickType: ClickType) async {
        let harness = Harness()
        let point = CGPoint(x: 10, y: 20)
        let modifiers: ClickModifiers = [.shift, .command]

        harness.engine.start(
            Self.configuration(clickType, target: .fixed(point), stopCondition: .afterClicks(3), modifiers: modifiers))
        #expect(await harness.waitForStop())

        let expected = MockEventPoster.Post(type: clickType, point: point, modifiers: modifiers)
        #expect(harness.poster.posts == Array(repeating: expected, count: 3))
    }

    @Test func passesNoModifiersForAPlainRun() async {
        let harness = Harness()

        harness.engine.start(Self.configuration(stopCondition: .afterClicks(2)))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts.map(\.modifiers) == [[], []])
    }

    @Test func eachRunUsesItsOwnModifiers() async {
        let harness = Harness()

        harness.engine.start(Self.configuration(stopCondition: .afterClicks(1), modifiers: .control))
        #expect(await harness.waitForStop())
        harness.engine.start(Self.configuration(stopCondition: .afterClicks(1), modifiers: [.option, .shift]))
        #expect(await waitUntil { harness.stops.count == 2 })

        #expect(harness.poster.posts.map(\.modifiers) == [.control, [.option, .shift]])
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

    // MARK: - Sequences

    @Test func sequenceClicksThePointsInOrderAndWraps() async {
        let harness = Harness()

        harness.engine.start(Self.configuration(target: Self.sequence(), stopCondition: .afterClicks(7)))
        #expect(await harness.waitForStop())

        let points = Self.sequencePoints
        #expect(harness.poster.posts.map(\.point) == points + points + [points[0]])
        #expect(harness.stops.values == [.conditionMet])
    }

    @Test(arguments: ClickType.allCases)
    func everySequencePointUsesTheSharedClickTypeAndModifiers(_ clickType: ClickType) async {
        let harness = Harness()
        let modifiers: ClickModifiers = [.option, .command]

        harness.engine.start(
            Self.configuration(
                clickType, target: Self.sequence(delay: 1), stopCondition: .afterClicks(6), modifiers: modifiers))
        #expect(await harness.waitForStop())

        #expect(harness.poster.count == 6)
        #expect(harness.poster.posts.allSatisfy { $0.type == clickType && $0.modifiers == modifiers })
        #expect(Set(harness.poster.posts.map { "\($0.point)" }).isSubset(of: Self.sequencePoints.map { "\($0)" }))
    }

    @Test func afterClicksCountsEveryPostedSequenceClick() async throws {
        let harness = Harness()

        harness.engine.start(Self.configuration(target: Self.sequence(delay: 1), stopCondition: .afterClicks(5)))
        #expect(await harness.waitForStop())
        try await Task.sleep(for: .milliseconds(10))
        await drain(harness.queue)

        #expect(harness.poster.count == 5)
        #expect(harness.counter.value == 5)
        #expect(harness.stops.values == [.conditionMet])
    }

    @Test func afterDurationEndsASequenceRun() async {
        let harness = Harness()

        harness.engine.start(
            Self.configuration(target: Self.sequence(delay: 10), stopCondition: .afterDuration(.milliseconds(35))))
        #expect(await harness.waitForStop())

        // Ticks are due at 10, 20 and 30 ms; the next one (40 ms) is past the limit.
        #expect((1...3).contains(harness.poster.count))
        #expect(harness.stops.values == [.conditionMet])
    }

    @Test func sequenceTickIndexPicksItsPoint() {
        let target = Self.sequence()
        let points = Self.sequencePoints
        let cursor = CGPoint(x: 1, y: 1)
        for index in 1...9 {
            #expect(ClickEngine.basePoint(for: target, tick: index, cursor: cursor) == points[(index - 1) % 3])
        }
        // A skipped tick skips its point: after tick 2, tick 6 clicks the third point, not the next one in line.
        #expect(ClickEngine.basePoint(for: target, tick: 6, cursor: cursor) == points[2])
        #expect(ClickEngine.basePoint(for: target, tick: 3_000_001, cursor: cursor) == points[0])
    }

    @Test func basePointForOtherTargets() {
        let cursor = CGPoint(x: 7, y: 8)
        let fixed = CGPoint(x: 70, y: 80)
        #expect(ClickEngine.basePoint(for: .currentCursor, tick: 5, cursor: cursor) == cursor)
        #expect(ClickEngine.basePoint(for: .currentCursor, tick: 5, cursor: nil) == nil)
        #expect(ClickEngine.basePoint(for: .fixed(fixed), tick: 5, cursor: cursor) == fixed)
        #expect(ClickEngine.basePoint(for: .sequence([]), tick: 1, cursor: cursor) == nil)
    }

    @Test func sequenceRunsOnTheDelaysOfItsPoints() async {
        let harness = Harness()
        let clock = ContinuousClock()
        let start = clock.now
        // Ticks are due at 1, 151 and 152 ms. With the 1 ms interval instead, all three would land within 3 ms.
        let target = ClickTarget.sequence([
            ClickPoint(point: CGPoint(x: 1, y: 1), delayMilliseconds: 1),
            ClickPoint(point: CGPoint(x: 2, y: 2), delayMilliseconds: 150),
        ])

        harness.engine.start(Self.configuration(milliseconds: 1, target: target, stopCondition: .afterClicks(3)))
        #expect(await harness.waitForStop())
        let elapsed = clock.now - start

        #expect(harness.poster.posts.map(\.point) == [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2), CGPoint(x: 1, y: 1)])
        #expect(elapsed >= .milliseconds(151))
    }

    @Test func sequenceJitterComesFromTheIntervalAndIsCappedByTheShortestDelay() async {
        let jitters = CallRecorder<Int>()
        let harness = Harness(jitterOffset: { interval in
            jitters.record(interval.effectiveJitterMilliseconds)
            return .zero
        })
        var configuration = Self.configuration(
            target: .sequence([
                ClickPoint(point: CGPoint(x: 1, y: 1), delayMilliseconds: 11),
                ClickPoint(point: CGPoint(x: 2, y: 2), delayMilliseconds: 40),
            ]),
            stopCondition: .afterClicks(3))
        configuration.interval = ClickInterval(milliseconds: 500, jitterMilliseconds: 100)

        harness.engine.start(configuration)
        #expect(await harness.waitForStop())

        // ±100 ms is requested, but the 11 ms delay caps it at ±5 ms.
        #expect(jitters.count >= 3)
        #expect(jitters.values.allSatisfy { $0 == 5 })
    }

    @Test func emptySequenceEndsAtOnceWithConditionMet() async throws {
        let offsets = CallRecorder<Int>()
        let harness = Harness(positionOffset: { radius in
            offsets.record(radius)
            return .zero
        })

        harness.engine.start(Self.configuration(target: .sequence([]), positionOffset: 10))
        #expect(await harness.waitForStop())
        try await Task.sleep(for: .milliseconds(20))
        await drain(harness.queue)

        #expect(harness.stops.values == [.conditionMet])
        #expect(!harness.engine.isRunning)
        #expect(harness.poster.count == 0)
        #expect(harness.counter.value == 0)
        #expect(harness.failsafe?.evaluations.isEmpty == true)
        #expect(offsets.count == 0)
    }

    @Test func canStartAgainAfterAnEmptySequence() async {
        let harness = Harness()

        harness.engine.start(Self.configuration(target: .sequence([])))
        #expect(await harness.waitForStop())
        harness.engine.start(Self.configuration(stopCondition: .afterClicks(2)))
        #expect(await waitUntil { harness.stops.count == 2 })

        #expect(harness.poster.count == 2)
        #expect(harness.stops.values == [.conditionMet, .conditionMet])
    }

    // MARK: - Position offset

    @Test func offsetMovesEveryFixedClick() async {
        let radii = CallRecorder<Int>()
        let harness = Harness(positionOffset: { radius in
            radii.record(radius)
            return Self.stubOffset
        })
        let point = CGPoint(x: 100, y: 100)

        harness.engine.start(
            Self.configuration(target: .fixed(point), stopCondition: .afterClicks(3), positionOffset: 25))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts.map(\.point) == Array(repeating: Self.offset(point), count: 3))
        #expect(radii.values == [25, 25, 25])
    }

    @Test func offsetMovesEverySequenceClick() async {
        let harness = Harness(positionOffset: { _ in Self.stubOffset })

        harness.engine.start(
            Self.configuration(target: Self.sequence(), stopCondition: .afterClicks(4), positionOffset: 50))
        #expect(await harness.waitForStop())

        let points = Self.sequencePoints
        #expect(harness.poster.posts.map(\.point) == (points + [points[0]]).map { Self.offset($0) })
    }

    @Test func eachClickDrawsItsOwnOffset() async {
        let draws = OSAllocatedUnfairLock(initialState: 0)
        let harness = Harness(positionOffset: { _ in
            draws.withLock { count in
                count += 1
                return CGVector(dx: count, dy: 0)
            }
        })
        let point = CGPoint(x: 100, y: 100)

        harness.engine.start(
            Self.configuration(target: .fixed(point), stopCondition: .afterClicks(3), positionOffset: 5))
        #expect(await harness.waitForStop())

        // Offsets are relative to the target every time, never to the previous click.
        #expect(harness.poster.posts.map(\.point.x) == [101, 102, 103])
    }

    @Test func offsetIsIgnoredForTheCurrentCursor() async {
        let radii = CallRecorder<Int>()
        let cursor = CGPoint(x: 640, y: 480)
        let harness = Harness(
            cursor: cursor,
            positionOffset: { radius in
                radii.record(radius)
                return Self.stubOffset
            })

        harness.engine.start(
            Self.configuration(target: .currentCursor, stopCondition: .afterClicks(3), positionOffset: 200))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts.map(\.point) == [cursor, cursor, cursor])
        #expect(radii.count == 0)
    }

    @Test(arguments: [0, -5])
    func offsetOfZeroOrLessNeverDraws(_ radius: Int) async {
        let radii = CallRecorder<Int>()
        let harness = Harness(positionOffset: { radius in
            radii.record(radius)
            return Self.stubOffset
        })
        let point = CGPoint(x: 10, y: 20)

        harness.engine.start(
            Self.configuration(target: .fixed(point), stopCondition: .afterClicks(2), positionOffset: radius))
        #expect(await harness.waitForStop())

        #expect(harness.poster.posts.map(\.point) == [point, point])
        #expect(radii.count == 0)
    }

    @Test func offsetRadiusIsClampedToTheSupportedRange() async {
        let radii = CallRecorder<Int>()
        let harness = Harness(positionOffset: { radius in
            radii.record(radius)
            return .zero
        })

        harness.engine.start(Self.configuration(stopCondition: .afterClicks(2), positionOffset: 5_000))
        #expect(await harness.waitForStop())

        #expect(radii.values == [200, 200])
    }

    @Test func defaultOffsetStaysInsideTheDisk() async {
        let harness = Harness()
        let point = CGPoint(x: 1_000, y: 1_000)

        harness.engine.start(
            Self.configuration(target: .fixed(point), stopCondition: .afterClicks(20), positionOffset: 30))
        #expect(await harness.waitForStop())

        #expect(harness.poster.count == 20)
        for post in harness.poster.posts {
            #expect(hypot(post.point.x - point.x, post.point.y - point.y) <= 30.000_001)
        }
        // With a 30-point radius, twenty identical draws would be a broken random source.
        #expect(Set(harness.poster.posts.map { "\($0.point)" }).count > 1)
    }

    @Test func ownWindowFailsafeChecksTheOffsetPointAndCornerUsesTheCursor() async {
        let failsafe = MockFailsafe(decision: .skipInsideOwnWindow)
        let cursor = CGPoint(x: 900, y: 700)
        let harness = Harness(failsafe: failsafe, cursor: cursor, positionOffset: { _ in Self.stubOffset })
        let point = CGPoint(x: 100, y: 100)

        harness.engine.start(Self.configuration(target: .fixed(point), positionOffset: 10))
        #expect(await waitUntil { failsafe.evaluations.count >= 3 })
        harness.engine.stop()
        await drain(harness.queue)

        #expect(harness.poster.count == 0)
        #expect(
            failsafe.evaluations.allSatisfy {
                $0 == MockFailsafe.Evaluation(cursor: cursor, target: Self.offset(point))
            })
    }

    @Test func sequenceFailsafeChecksEachOffsetPoint() async {
        let failsafe = MockFailsafe()
        let cursor = CGPoint(x: 900, y: 700)
        let harness = Harness(failsafe: failsafe, cursor: cursor, positionOffset: { _ in Self.stubOffset })

        harness.engine.start(
            Self.configuration(target: Self.sequence(), stopCondition: .afterClicks(3), positionOffset: 10))
        #expect(await harness.waitForStop())

        let expected = Self.sequencePoints.map { MockFailsafe.Evaluation(cursor: cursor, target: Self.offset($0)) }
        #expect(failsafe.evaluations == expected)
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
