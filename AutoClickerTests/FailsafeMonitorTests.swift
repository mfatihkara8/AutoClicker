import CoreGraphics
import Dispatch
import Testing

@testable import AutoClicker

struct FailsafeMonitorTests {
    // MARK: - Fixtures

    /// 1440x900 primary with a 1920x1080 secondary to its right, bottom edges aligned in AppKit.
    ///
    /// In CG space the primary is `(0, 0, 1440, 900)` and the secondary is `(1440, -180, 1920, 1080)`, so the
    /// secondary's corners are `(1440, -180)`, `(3360, -180)`, `(1440, 900)` and `(3360, 900)`.
    private static let sideBySide = ScreenGeometry(appKitScreenFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900),
        CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    ])

    /// A single 1440x900 screen.
    private static let singleScreen = ScreenGeometry(appKitScreenFrames: [
        CGRect(x: 0, y: 0, width: 1440, height: 900)
    ])

    /// An own window in CG space, well away from every corner.
    private static let window = CGRect(x: 200, y: 100, width: 400, height: 300)

    /// A point inside neither the window nor any corner tolerance.
    private static let neutralPoint = CGPoint(x: 900, y: 600)

    // MARK: - Corner check

    @Test(arguments: [
        // Primary top-left, at 0 and 2 px.
        CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 2), CGPoint(x: 2, y: 0),
        // Primary bottom-left.
        CGPoint(x: 0, y: 900), CGPoint(x: 2, y: 898),
        // Secondary top-right (the cursor can reach about maxX - 1).
        CGPoint(x: 3360, y: -180), CGPoint(x: 3358, y: -178), CGPoint(x: 3359, y: -179),
        // Secondary bottom-right.
        CGPoint(x: 3360, y: 900), CGPoint(x: 3358, y: 898),
    ])
    func stopsWithinTwoPixelsOfACorner(cursor: CGPoint) {
        let monitor = FailsafeMonitor(geometry: Self.sideBySide)
        #expect(monitor.shouldStop(cursor: cursor))
    }

    @Test(arguments: [
        // 3 px away on one or both axes.
        CGPoint(x: 3, y: 3), CGPoint(x: 3, y: 0), CGPoint(x: 0, y: 3),
        CGPoint(x: 3357, y: -177), CGPoint(x: 3360, y: -177), CGPoint(x: 3357, y: 900),
        // On an edge, but far from a corner.
        CGPoint(x: 0, y: 450), CGPoint(x: 720, y: 0),
        // Middle of each screen.
        CGPoint(x: 720, y: 450), CGPoint(x: 2400, y: 360),
    ])
    func doesNotStopThreeOrMorePixelsFromACorner(cursor: CGPoint) {
        let monitor = FailsafeMonitor(geometry: Self.sideBySide)
        #expect(!monitor.shouldStop(cursor: cursor))
    }

    @Test func honorsACustomCornerTolerance() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, cornerTolerance: 5)
        #expect(monitor.shouldStop(cursor: CGPoint(x: 5, y: 5)))
        #expect(!monitor.shouldStop(cursor: CGPoint(x: 6, y: 5)))
    }

    @Test func neverStopsWithoutScreens() {
        let monitor = FailsafeMonitor(geometry: ScreenGeometry(appKitScreenFrames: []))
        #expect(!monitor.shouldStop(cursor: .zero))
    }

    // MARK: - Own-window check

    @Test(arguments: [
        CGPoint(x: 400, y: 250),  // center
        CGPoint(x: 200, y: 100),  // top-left corner: the min edges are inside
        CGPoint(x: 200, y: 250),  // left edge
        CGPoint(x: 400, y: 100),  // top edge
        CGPoint(x: 599.5, y: 399.5),  // just inside the max edges
    ])
    func detectsPointsInsideTheOwnWindow(point: CGPoint) {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(monitor.isInsideOwnWindow(point))
    }

    @Test(arguments: [
        CGPoint(x: 600, y: 250),  // right edge: frames are half-open like `CGRect.contains`
        CGPoint(x: 400, y: 400),  // bottom edge
        CGPoint(x: 199, y: 250),  // just left of the window
        CGPoint(x: 400, y: 99),  // just above the window
        CGPoint(x: 900, y: 600),  // far away
    ])
    func ignoresPointsOutsideTheOwnWindow(point: CGPoint) {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(!monitor.isInsideOwnWindow(point))
    }

    @Test func checksEveryOwnWindow() {
        let settings = CGRect(x: 1000, y: 500, width: 200, height: 150)
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window, settings])
        #expect(monitor.isInsideOwnWindow(CGPoint(x: 400, y: 250)))
        #expect(monitor.isInsideOwnWindow(CGPoint(x: 1100, y: 575)))
        #expect(!monitor.isInsideOwnWindow(CGPoint(x: 800, y: 450)))
    }

    @Test func noOwnWindowsMeansNothingIsInside() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen)
        #expect(!monitor.isInsideOwnWindow(CGPoint(x: 400, y: 250)))
    }

    // MARK: - Evaluate

    @Test func proceedsWhenNoFailsafeApplies() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(monitor.evaluate(cursor: Self.neutralPoint, target: Self.neutralPoint) == .proceed)
    }

    @Test func stopsWhenTheCursorIsInACorner() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(monitor.evaluate(cursor: CGPoint(x: 1, y: 1), target: Self.neutralPoint) == .stopCornerReached)
    }

    @Test func skipsWhenTheTargetIsInsideTheOwnWindow() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(
            monitor.evaluate(cursor: Self.neutralPoint, target: CGPoint(x: 400, y: 250)) == .skipInsideOwnWindow)
    }

    @Test func cornerStopTakesPrecedenceOverOwnWindowSkip() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(monitor.evaluate(cursor: CGPoint(x: 0, y: 0), target: CGPoint(x: 400, y: 250)) == .stopCornerReached)
    }

    @Test func cornerCheckUsesTheCursorNotTheTarget() {
        // A fixed target sitting in a corner must not stop the run; only the cursor position counts.
        let monitor = FailsafeMonitor(geometry: Self.singleScreen)
        #expect(monitor.evaluate(cursor: Self.neutralPoint, target: CGPoint(x: 0, y: 0)) == .proceed)
    }

    @Test func ownWindowCheckUsesTheTargetNotTheCursor() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(monitor.evaluate(cursor: CGPoint(x: 400, y: 250), target: Self.neutralPoint) == .proceed)
    }

    @Test func nilCursorSkipsOnlyTheCornerCheck() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        #expect(monitor.evaluate(cursor: nil, target: Self.neutralPoint) == .proceed)
        #expect(monitor.evaluate(cursor: nil, target: CGPoint(x: 0, y: 0)) == .proceed)
        #expect(monitor.evaluate(cursor: nil, target: CGPoint(x: 400, y: 250)) == .skipInsideOwnWindow)
    }

    // MARK: - Updates

    @Test func geometryUpdateTakesEffect() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen)
        let secondaryCorner = CGPoint(x: 3360, y: -180)
        #expect(!monitor.shouldStop(cursor: secondaryCorner))

        monitor.update(geometry: Self.sideBySide)
        #expect(monitor.shouldStop(cursor: secondaryCorner))
        #expect(monitor.evaluate(cursor: secondaryCorner, target: Self.neutralPoint) == .stopCornerReached)

        monitor.update(geometry: Self.singleScreen)
        #expect(!monitor.shouldStop(cursor: secondaryCorner))
    }

    @Test func ownWindowFramesUpdateTakesEffect() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen)
        let point = CGPoint(x: 400, y: 250)
        #expect(!monitor.isInsideOwnWindow(point))

        monitor.update(ownWindowFrames: [Self.window])
        #expect(monitor.isInsideOwnWindow(point))
        #expect(monitor.evaluate(cursor: Self.neutralPoint, target: point) == .skipInsideOwnWindow)

        // Moving the window replaces the old frames rather than adding to them.
        monitor.update(ownWindowFrames: [CGRect(x: 800, y: 500, width: 100, height: 100)])
        #expect(!monitor.isInsideOwnWindow(point))

        monitor.update(ownWindowFrames: [])
        #expect(!monitor.isInsideOwnWindow(CGPoint(x: 850, y: 550)))
    }

    @Test func concurrentEvaluateAndUpdateDoNotCrash() {
        let monitor = FailsafeMonitor(geometry: Self.singleScreen, ownWindowFrames: [Self.window])
        let geometries = [Self.singleScreen, Self.sideBySide]
        DispatchQueue.concurrentPerform(iterations: 2_000) { index in
            switch index % 3 {
            case 0:
                monitor.update(geometry: geometries[index % 2])
            case 1:
                monitor.update(ownWindowFrames: index % 2 == 0 ? [] : [Self.window])
            default:
                _ = monitor.evaluate(cursor: CGPoint(x: index % 1440, y: index % 900), target: Self.neutralPoint)
            }
        }
        // The state is whatever the last update left behind, but it must still be consistent and usable.
        #expect(monitor.shouldStop(cursor: .zero))
    }
}
