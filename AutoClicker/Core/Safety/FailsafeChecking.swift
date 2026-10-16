import CoreGraphics

/// What the engine should do with the current tick, as decided by the failsafes (SPEC section 3.4).
enum FailsafeDecision: Sendable, Equatable {
    /// Post the click.
    case proceed
    /// Skip this click without counting it: the target lies inside one of the app's own windows.
    case skipInsideOwnWindow
    /// Stop the run: the cursor is within the corner tolerance of a screen corner.
    case stopCornerReached
}

/// The failsafe check the engine runs before every click.
///
/// `ClickEngine` depends only on this protocol, so its tests can drive every decision without real
/// screens or windows. `FailsafeMonitor` is the production implementation.
protocol FailsafeChecking: Sendable {
    /// Decides what to do with one tick.
    ///
    /// - Parameters:
    ///   - cursor: The current cursor position in CG global space, or `nil` if it could not be read.
    ///   - target: The resolved click point in CG global space.
    /// - Returns: The decision for this tick. It is called on the engine's serial click queue.
    func evaluate(cursor: CGPoint?, target: CGPoint) -> FailsafeDecision
}
