import AppKit
import CoreGraphics
import os

/// The production failsafe: stops the run when the cursor reaches a screen corner, and skips clicks whose target
/// lies inside one of the app's own windows (SPEC section 3.4).
///
/// The engine calls `evaluate(cursor:target:)` on its serial click queue for every click, while the main actor
/// pushes new screen and window snapshots through the `update` methods. Both sides meet in an
/// `OSAllocatedUnfairLock`, so the class is `Sendable` without `@unchecked` and the click loop never hops to the main
/// actor. The lock is held only for a short, allocation-free scan, which keeps the per-click cost negligible.
final class FailsafeMonitor: FailsafeChecking {
    private struct State {
        var geometry: ScreenGeometry
        var ownWindowFrames: [CGRect]
    }

    private let state: OSAllocatedUnfairLock<State>
    private let cornerTolerance: CGFloat

    /// Creates a monitor from main-actor snapshots.
    ///
    /// - Parameters:
    ///   - geometry: The current screen configuration, usually `ScreenGeometry.current()`.
    ///   - ownWindowFrames: The frames of the app's own visible windows in CG global space, usually
    ///     `FailsafeMonitor.ownWindowFrames(geometry:)`.
    ///   - cornerTolerance: How close (per axis, in points) the cursor must get to a corner to stop the run.
    init(geometry: ScreenGeometry, ownWindowFrames: [CGRect] = [], cornerTolerance: CGFloat = 2) {
        self.state = OSAllocatedUnfairLock(initialState: State(geometry: geometry, ownWindowFrames: ownWindowFrames))
        self.cornerTolerance = cornerTolerance
    }

    // MARK: - Updates

    /// Replaces the screen snapshot, for example after the display configuration changed or before a run starts.
    func update(geometry: ScreenGeometry) {
        state.withLock { $0.geometry = geometry }
    }

    /// Replaces the own-window snapshot. The frames are in CG global space and replace, not extend, the old ones.
    func update(ownWindowFrames: [CGRect]) {
        state.withLock { $0.ownWindowFrames = ownWindowFrames }
    }

    // MARK: - Checks

    /// Whether `cursor` (CG global space) is within `cornerTolerance` of any screen corner.
    func shouldStop(cursor: CGPoint) -> Bool {
        let tolerance = cornerTolerance
        return state.withLock { $0.geometry.isNearCorner(cursor, tolerance: tolerance) }
    }

    /// Whether `point` (CG global space) lies inside one of the app's own windows.
    ///
    /// Frames are half-open like `CGRect.contains`: a point on a window's min edge is inside, one on its max edge is
    /// not.
    func isInsideOwnWindow(_ point: CGPoint) -> Bool {
        state.withLock { $0.ownWindowFrames.contains { $0.contains(point) } }
    }

    // MARK: - FailsafeChecking

    /// Decides what to do with one tick.
    ///
    /// The corner check comes first because it ends the run, which is the safer outcome when both apply. A `nil`
    /// cursor skips only the corner check: an unreadable position must not stop the run as if it were at `.zero`,
    /// and the own-window check needs only the target.
    func evaluate(cursor: CGPoint?, target: CGPoint) -> FailsafeDecision {
        let tolerance = cornerTolerance
        // One lock acquisition per click, so both checks see the same snapshot.
        return state.withLock { state in
            if let cursor, state.geometry.isNearCorner(cursor, tolerance: tolerance) {
                return .stopCornerReached
            }
            if state.ownWindowFrames.contains(where: { $0.contains(target) }) {
                return .skipInsideOwnWindow
            }
            return .proceed
        }
    }

    // MARK: - Snapshot

    /// Snapshots the frames of the app's own visible windows in CG global space.
    ///
    /// `NSWindow` is main-actor bound, so the caller takes this snapshot on the main actor and passes the result to
    /// `update(ownWindowFrames:)`. Hidden and minimized windows are left out because clicks cannot land on them.
    @MainActor
    static func ownWindowFrames(geometry: ScreenGeometry) -> [CGRect] {
        NSApplication.shared.windows
            .filter { $0.isVisible && !$0.isMiniaturized }
            .map { geometry.cgRect(fromAppKit: $0.frame) }
    }
}
