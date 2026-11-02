import Carbon
import CoreGraphics
import Dispatch
import Foundation
import Testing
import os

@testable import AutoClicker

/// Checks the Phase 2 success criteria (docs/GOALS.md) as closely as unit tests allow.
///
/// The engine tests run the real `ClickEngine`, `ClickScheduler` (real `ContinuousClock`), `FailsafeMonitor`, default
/// jitter and default position offset source, with only the event poster and the cursor replaced. SC-14 runs the real
/// `MainViewModel` and `SettingsStore` on a throwaway `UserDefaults` suite. SC-15 (no CPU or memory regression) needs
/// the real app under load and is measured as described in docs/RELEASING.md, not here.
///
/// Serialized because SC-12 measures real time: running the other tests of this suite next to it would only add load.
@Suite(.serialized)
struct Phase2AcceptanceTests {
    /// A real engine on test doubles that never touch the system.
    private struct Harness {
        /// The single test screen, 1000 × 800 points, used by the real failsafe's corner check.
        static let geometry = ScreenGeometry(appKitScreenFrames: [CGRect(x: 0, y: 0, width: 1000, height: 800)])
        /// The cursor, well away from every corner, so the corner failsafe never ends a run.
        static let cursor = CGPoint(x: 500, y: 400)

        let engine: ClickEngine
        let poster = MockEventPoster()
        let queue = DispatchQueue(label: "Phase2AcceptanceTests", qos: .userInteractive)
        let stops = CallRecorder<StopReason>()

        init(jitterOffset: @escaping @Sendable (ClickInterval) -> Duration = { $0.jitterOffset() }) {
            let cursor = Self.cursor
            engine = ClickEngine(
                poster: poster,
                counter: ClickCounter(),
                failsafe: FailsafeMonitor(geometry: Self.geometry),
                cursorLocation: { cursor },
                queue: queue,
                jitterOffset: jitterOffset)
            let stops = stops
            engine.onStop = { stops.record($0) }
        }

        /// Starts `configuration`, waits for its run to end on its own and returns the posted points.
        func run(_ configuration: ClickConfiguration, timeout: Duration = .seconds(5)) async -> [CGPoint]? {
            engine.start(configuration)
            let stops = stops
            guard await waitUntil(timeout: timeout, { stops.count >= 1 }) else {
                engine.stop()
                return nil
            }
            await drain(queue)
            return poster.posts.map(\.point)
        }
    }

    /// How a run's posted points follow a sequence's cyclic order.
    private struct SequenceOrder {
        /// The index in the sequence of every posted point, or `nil` for a point that is not in the sequence.
        let indices: [Int?]
        /// The number of consecutive posts that do not follow the cyclic order.
        let breaks: Int
        /// The ticks the order implies were skipped, modulo the sequence length: before the first post, between posts
        /// and after the last post up to `lastTick`. A skipped whole cycle is invisible in the order, so this is only
        /// known modulo the length.
        let impliedSkipsModuloLength: Int

        init(posted: [CGPoint], sequence: [CGPoint], lastTick: Int) {
            let count = sequence.count
            indices = posted.map { sequence.firstIndex(of: $0) }
            let known = indices.compactMap { $0 }
            var breaks = 0
            var skips = known.first ?? 0
            for (previous, next) in zip(known, known.dropFirst()) {
                let gap = ((next - previous - 1) % count + count) % count
                breaks += gap == 0 ? 0 : 1
                skips += gap
            }
            if let last = known.last {
                skips += ((lastTick - 1) % count - last + count) % count
            }
            self.breaks = breaks
            impliedSkipsModuloLength = skips % count
        }
    }

    private static func distance(_ point: CGPoint, _ center: CGPoint) -> CGFloat {
        hypot(point.x - center.x, point.y - center.y)
    }

    /// The quadrants around `center` that `points` fall into, numbered 0 to 3. Points on an axis count for none.
    private static func quadrants(of points: [CGPoint], around center: CGPoint) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for point in points where point.x != center.x && point.y != center.y {
            let quadrant = (point.x > center.x ? 0 : 1) + (point.y > center.y ? 0 : 2)
            counts[quadrant, default: 0] += 1
        }
        return counts
    }

    /// Records a measurement as a test attachment, so the numbers end up in the result bundle, and prints it.
    private static func report(_ text: String) {
        print(text)
        Attachment.record(text, named: "\(text.prefix(while: { $0 != ":" })).txt")
    }

    /// A small slack for floating point error in the offset distance.
    private static let epsilon: CGFloat = 1e-9

    // MARK: - SC-12: sequence order and timing

    /// Same 1 : 2 : 3 ratios as SC-12's 200, 400 and 600 ms, scaled down by ten.
    private static let sequencePoints = [CGPoint(x: 100, y: 100), CGPoint(x: 600, y: 150), CGPoint(x: 300, y: 700)]

    private static func sequence(delays: [Int]) -> ClickTarget {
        .sequence(
            zip(sequencePoints, delays).map { ClickPoint(point: $0, delayMilliseconds: $1) })
    }

    /// SC-12, scaled: 20, 40 and 60 ms for 6 s is 50 cycles of 120 ms, so 150 clicks, the last one due exactly at the
    /// limit, in the order p0, p1, p2, p0, …
    @Test func sequenceClicksItsPointsInOrderAndKeepsTheCount() async throws {
        let harness = Harness()
        let expected = 150
        let clock = ContinuousClock()
        let start = clock.now

        let configuration = ClickConfiguration(
            clickType: .left,
            interval: ClickInterval(milliseconds: 100),
            target: Self.sequence(delays: [20, 40, 60]),
            stopCondition: .afterDuration(.seconds(6)))
        let posted = try #require(await harness.run(configuration, timeout: .seconds(15)))
        let elapsed = clock.now - start

        let order = SequenceOrder(posted: posted, sequence: Self.sequencePoints, lastTick: expected)
        let skipped = expected - posted.count
        Self.report(
            "SC-12: \(posted.count) clicks (expected \(expected)), \(order.breaks) order breaks, run took \(elapsed)")

        #expect(harness.stops.values == [.conditionMet])
        #expect(order.indices.allSatisfy { $0 != nil }, "Every click lands on a sequence point")
        #expect(abs(posted.count - expected) <= expected * 2 / 100, "Within ±2% of \(expected)")
        if skipped == 0 {
            // Nothing was skipped, so the order must be exactly p0, p1, p2, p0, …
            #expect(order.indices.first == 0)
            #expect(order.breaks == 0)
            #expect(
                order.indices == (0..<expected).map { $0 % Self.sequencePoints.count },
                "Strict cyclic order")
        } else {
            // A very loaded machine skipped ticks. A skipped tick skips its point, so the order may only break where
            // ticks are missing: the skips the order implies must add up to the missing clicks.
            Self.report("SC-12: \(skipped) ticks were skipped; checking the order against the skips instead")
            #expect(order.impliedSkipsModuloLength == skipped % Self.sequencePoints.count)
            #expect(order.breaks <= skipped)
        }
        #expect(elapsed >= .seconds(6))
    }

    /// SC-12 with jitter: every deadline moves by up to ±5 ms, but deadlines stay at least 1 ms apart, so the order is
    /// unchanged.
    @Test func sequenceWithJitterKeepsItsOrder() async throws {
        let offsets = CallRecorder<Duration>()
        let harness = Harness(jitterOffset: { interval in
            let offset = interval.jitterOffset()
            offsets.record(offset)
            return offset
        })

        // 10 cycles of 120 ms. Tick 30 is due at 1200 ms plus its jitter, so it is posted only when that jitter is not
        // positive: 29 or 30 clicks.
        let configuration = ClickConfiguration(
            clickType: .left,
            interval: ClickInterval(milliseconds: 100, jitterMilliseconds: 5),
            target: Self.sequence(delays: [20, 40, 60]),
            stopCondition: .afterDuration(.milliseconds(1_200)))
        let posted = try #require(await harness.run(configuration))

        let order = SequenceOrder(posted: posted, sequence: Self.sequencePoints, lastTick: posted.count)
        let drawn = offsets.values
        Self.report(
            "SC-12 jitter: \(posted.count) clicks, \(order.breaks) order breaks, offsets drawn: "
                + "\(drawn.count), nonzero: \(drawn.filter { $0 != .zero }.count)")

        #expect(drawn.contains { $0 != .zero }, "The default jitter source actually moved deadlines")
        #expect(drawn.allSatisfy { (.milliseconds(-5) ... .milliseconds(5)).contains($0) })
        #expect(order.indices.allSatisfy { $0 != nil })
        if (29...30).contains(posted.count) {
            #expect(order.indices.first == 0)
            #expect(order.breaks == 0)
        } else {
            Self.report("SC-12 jitter: only \(posted.count) clicks, so ticks were skipped; order breaks are expected")
            #expect(posted.count >= 27)
        }
    }

    // MARK: - SC-13: position offset

    /// SC-13: with a 20 pt offset on a fixed target, every click lands within 20 pt of it and the positions vary.
    @Test func offsetKeepsFixedClicksWithinTheRadiusAndVariesThem() async throws {
        let harness = Harness()
        let target = CGPoint(x: 400, y: 300)
        let clicks = 200

        let configuration = ClickConfiguration(
            clickType: .left,
            interval: ClickInterval(milliseconds: 1),
            target: .fixed(target),
            stopCondition: .afterClicks(clicks),
            positionOffset: 20)
        let posted = try #require(await harness.run(configuration))

        let distances = posted.map { Self.distance($0, target) }
        let maxDistance = distances.max() ?? 0
        let meanDistance = distances.reduce(0, +) / CGFloat(max(distances.count, 1))
        let distinct = Set(posted.map { "\($0.x),\($0.y)" }).count
        let quadrants = Self.quadrants(of: posted, around: target)
        let width = (posted.map(\.x).max() ?? 0) - (posted.map(\.x).min() ?? 0)
        let height = (posted.map(\.y).max() ?? 0) - (posted.map(\.y).min() ?? 0)
        Self.report(
            "SC-13 fixed: \(posted.count) clicks, max distance \(maxDistance), mean \(meanDistance), "
                + "\(distinct) distinct, quadrants \(quadrants.sorted { $0.key < $1.key }), "
                + "spread \(width) × \(height)")

        #expect(posted.count == clicks)
        #expect(maxDistance <= 20 + Self.epsilon, "Every click within 20 pt of the target")
        #expect(distinct >= clicks * 95 / 100, "The positions vary")
        #expect((0..<4).allSatisfy { quadrants[$0, default: 0] >= 20 }, "Every quadrant of the disk is used")
        // Uniform over the disk: the mean distance is 2/3 of the radius (13.3 pt), and almost every draw is past 5 pt.
        #expect((10...17).contains(meanDistance))
        #expect(maxDistance > 15)
        #expect(width > 30 && height > 30)
    }

    /// SC-13 for a sequence: each point gets its own fresh offset within the radius.
    @Test func offsetKeepsEverySequencePointWithinTheRadius() async throws {
        let harness = Harness()
        let clicks = 201

        let configuration = ClickConfiguration(
            clickType: .left,
            interval: ClickInterval(milliseconds: 100),
            target: Self.sequence(delays: [1, 2, 2]),
            stopCondition: .afterClicks(clicks),
            positionOffset: 20)
        let posted = try #require(await harness.run(configuration))

        // The points are hundreds of points apart, so each click belongs to the nearest one.
        var byPoint: [Int: [CGPoint]] = [:]
        var maxDistance: CGFloat = 0
        for click in posted {
            let nearest = Self.sequencePoints.indices.min {
                Self.distance(click, Self.sequencePoints[$0]) < Self.distance(click, Self.sequencePoints[$1])
            }
            guard let nearest else { continue }
            maxDistance = max(maxDistance, Self.distance(click, Self.sequencePoints[nearest]))
            byPoint[nearest, default: []].append(click)
        }
        let summary = byPoint.sorted { $0.key < $1.key }.map { index, clicks in
            let distinct = Set(clicks.map { "\($0.x),\($0.y)" }).count
            let quadrants = Self.quadrants(of: clicks, around: Self.sequencePoints[index])
            return "p\(index): \(clicks.count) clicks, \(distinct) distinct, \(quadrants.count) quadrants"
        }
        Self.report("SC-13 sequence: max distance \(maxDistance); \(summary.joined(separator: "; "))")

        #expect(posted.count == clicks)
        #expect(maxDistance <= 20 + Self.epsilon, "Every click within 20 pt of its point")
        for index in Self.sequencePoints.indices {
            let clicks = byPoint[index] ?? []
            #expect(clicks.count >= 30, "Point \(index) is clicked")
            #expect(Set(clicks.map { "\($0.x),\($0.y)" }).count >= clicks.count * 95 / 100, "Point \(index) varies")
            #expect(Self.quadrants(of: clicks, around: Self.sequencePoints[index]).count == 4)
        }
    }

    /// SC-13 boundary (ADR-012): the offset is ignored for the current cursor, so it cannot walk away from it.
    @Test func offsetIsIgnoredForTheCurrentCursor() async throws {
        let harness = Harness()

        let configuration = ClickConfiguration(
            clickType: .left,
            interval: ClickInterval(milliseconds: 1),
            target: .currentCursor,
            stopCondition: .afterClicks(100),
            positionOffset: 20)
        let posted = try #require(await harness.run(configuration))

        #expect(posted == Array(repeating: Harness.cursor, count: 100))
    }

    // MARK: - SC-14: profiles survive a relaunch

    /// A configuration with every field away from its default.
    private static let profileConfiguration = ClickConfiguration(
        clickType: .double,
        interval: ClickInterval(minutes: 1, seconds: 2, milliseconds: 345, jitterMilliseconds: 17),
        target: .sequence([
            ClickPoint(point: CGPoint(x: 12.5, y: 34.25), delayMilliseconds: 150),
            ClickPoint(point: CGPoint(x: 640, y: 480), delayMilliseconds: 2_500),
            ClickPoint(point: CGPoint(x: 1_919.75, y: 1_079), delayMilliseconds: 86_400_000),
        ]),
        stopCondition: .afterDuration(.milliseconds(90_500)),
        modifiers: [.command, .shift],
        positionOffset: 37)

    /// The working configuration the user switches to after saving the profile.
    private static let otherConfiguration = ClickConfiguration(
        clickType: .right,
        interval: ClickInterval(milliseconds: 250),
        target: .fixed(CGPoint(x: 10, y: 20)),
        stopCondition: .afterClicks(5),
        modifiers: .option,
        positionOffset: 0)

    /// SC-14: a saved profile survives quitting and relaunching, and applying it restores every click setting while the
    /// global start/stop shortcut stays as it was.
    @MainActor
    @Test func savedProfileSurvivesARelaunchAndRestoresEverySetting() throws {
        let saved = Self.profileConfiguration
        let defaultConfiguration = ClickConfiguration.default
        // The profile really covers every field.
        #expect(saved.clickType != defaultConfiguration.clickType)
        #expect(saved.interval != defaultConfiguration.interval)
        #expect(saved.interval.jitterMilliseconds != 0)
        #expect(saved.target != defaultConfiguration.target)
        #expect(saved.stopCondition != defaultConfiguration.stopCondition)
        #expect(saved.modifiers != defaultConfiguration.modifiers)
        #expect(saved.positionOffset != defaultConfiguration.positionOffset)

        let harness = try MainViewModelHarness()
        let shortcut = Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), keyLabel: "K")
        harness.store.save(AppSettings(configuration: .default, toggleHotkey: shortcut))

        // First launch: save the profile, then keep editing the working configuration.
        var firstLaunch: MainViewModel? = harness.makeViewModel()
        firstLaunch?.activate()
        firstLaunch?.configuration = saved
        #expect(firstLaunch?.saveNewProfile(named: "Acceptance") == nil)
        let profileID = try #require(firstLaunch?.activeProfileID)
        firstLaunch?.configuration = Self.otherConfiguration
        firstLaunch?.flushPendingSave()
        // Quit.
        firstLaunch = nil
        #expect(harness.hotkeys.registeredHotkeys.isEmpty)

        // Relaunch: a new store on a new `UserDefaults` handle for the same suite, and a new view model.
        let relaunchDefaults = try #require(UserDefaults(suiteName: harness.suiteName))
        let relaunched = harness.makeViewModel(settingsStore: SettingsStore(defaults: relaunchDefaults))
        relaunched.activate()

        #expect(relaunched.configuration == Self.otherConfiguration)
        #expect(relaunched.profiles == [Profile(id: profileID, name: "Acceptance", configuration: saved)])
        #expect(relaunched.activeProfileID == profileID)
        #expect(relaunched.isActiveProfileModified)
        #expect(relaunched.toggleHotkey == shortcut)

        #expect(relaunched.applyProfile(id: profileID))

        #expect(relaunched.configuration == saved)
        #expect(relaunched.isActiveProfileModified == false)
        #expect(relaunched.toggleHotkey == shortcut)
        #expect(harness.hotkeys.isRegistered(shortcut))
        // And what the apply saved survives yet another launch.
        let reloaded = SettingsStore(defaults: relaunchDefaults).load()
        #expect(reloaded.configuration == saved)
        #expect(reloaded.toggleHotkey == shortcut)
        #expect(reloaded.activeProfileID == profileID)
    }
}
