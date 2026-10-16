import AppKit
import CoreGraphics

/// The only place in the app that converts between AppKit and CG global coordinates (ADR-006).
///
/// - AppKit global space (`NSScreen.frame`, `NSEvent.mouseLocation`) has its origin at the
///   bottom-left of the primary screen, with y growing upwards.
/// - CG global space (`CGEvent.location`, posted events) has its origin at the top-left of the
///   primary screen, with y growing downwards.
///
/// Both spaces share the x axis, so a conversion only flips y around the primary screen's
/// height: `y_cg = primaryHeight - y_appkit`. The type is a pure value built from a snapshot of
/// screen frames, which keeps the math unit-testable without real displays and lets the engine
/// use it from its serial queue.
struct ScreenGeometry: Sendable, Equatable {
    /// Screen frames in CG global space, in the same order as the AppKit frames passed to `init`.
    let cgScreenFrames: [CGRect]

    /// The four geometric corners of every screen in CG global space, four entries per screen.
    ///
    /// Corners sit on the frame's max edges (for example `maxX`), even though the cursor can only
    /// reach about `maxX - 1`; that is still inside the failsafe tolerance of 2 px.
    let cgCorners: [CGPoint]

    /// The height that defines the flip between the two spaces. `0` when there are no screens.
    private let primaryHeight: CGFloat

    /// Creates a geometry from screen frames in AppKit global space.
    ///
    /// - Parameter appKitScreenFrames: The frames of all screens, primary (menu bar) screen first,
    ///   as `NSScreen.screens.map(\.frame)` returns them. The primary frame has its origin at
    ///   `(0, 0)` by AppKit's definition. An empty list yields a geometry without screens or
    ///   corners, whose conversions only mirror y around zero.
    init(appKitScreenFrames: [CGRect]) {
        let primaryHeight = appKitScreenFrames.first?.height ?? 0
        let cgFrames = appKitScreenFrames.map { Self.flip($0, primaryHeight: primaryHeight) }
        self.primaryHeight = primaryHeight
        self.cgScreenFrames = cgFrames
        self.cgCorners = cgFrames.flatMap { frame in
            [
                CGPoint(x: frame.minX, y: frame.minY),
                CGPoint(x: frame.maxX, y: frame.minY),
                CGPoint(x: frame.minX, y: frame.maxY),
                CGPoint(x: frame.maxX, y: frame.maxY),
            ]
        }
    }

    /// Builds a geometry from the live screen configuration.
    ///
    /// `NSScreen` is main-actor bound, so this must run on the main actor. Take a fresh snapshot
    /// whenever the screen configuration may have changed (for example on every engine start),
    /// then hand the resulting value to other threads.
    @MainActor
    static func current() -> ScreenGeometry {
        ScreenGeometry(appKitScreenFrames: NSScreen.screens.map(\.frame))
    }

    /// Reads the current cursor position in CG global space.
    ///
    /// Returns `nil` when the system cannot create the event (for example without a window
    /// server session) rather than a made-up position such as `.zero`, which would sit exactly on
    /// a screen corner and trip the failsafe. Safe to call from any thread, so the engine reads it
    /// on its serial click queue.
    static func currentCursorLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    // MARK: - Conversion

    /// Converts a point from AppKit global space to CG global space.
    func cgPoint(fromAppKit point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Converts a point from CG global space to AppKit global space.
    func appKitPoint(fromCG point: CGPoint) -> CGPoint {
        // The flip is its own inverse.
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Converts a rect from AppKit global space to CG global space.
    func cgRect(fromAppKit rect: CGRect) -> CGRect {
        Self.flip(rect, primaryHeight: primaryHeight)
    }

    /// Converts a rect from CG global space to AppKit global space.
    func appKitRect(fromCG rect: CGRect) -> CGRect {
        Self.flip(rect, primaryHeight: primaryHeight)
    }

    // MARK: - Queries

    /// Returns the CG frame of the screen that contains `cgPoint`, or `nil` if it is off-screen.
    ///
    /// Frames are half-open (`minX <= x < maxX`), so a point on a shared edge belongs to the
    /// screen that starts there.
    func screenFrameContaining(_ cgPoint: CGPoint) -> CGRect? {
        cgScreenFrames.first { $0.contains(cgPoint) }
    }

    /// Whether `point` (CG global space) lies within `tolerance` points of any screen corner.
    ///
    /// The check is per axis (a square around each corner), so both `|dx|` and `|dy|` must be at
    /// most `tolerance`. The corner failsafe uses this before every click.
    func isNearCorner(_ point: CGPoint, tolerance: CGFloat = 2) -> Bool {
        cgCorners.contains { corner in
            abs(point.x - corner.x) <= tolerance && abs(point.y - corner.y) <= tolerance
        }
    }

    // MARK: - Private

    /// Flips a rect between the two spaces. The top edge in one space becomes the origin edge in
    /// the other, so the height is subtracted along with the origin.
    private static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
