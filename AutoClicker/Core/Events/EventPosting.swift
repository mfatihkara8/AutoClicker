import CoreGraphics

/// Posts synthetic mouse clicks to the system.
///
/// This is the engine's only route to `CGEvent`. The engine calls it from its serial background queue, never from the
/// main actor, so conforming types must be safe to use from any thread. Tests substitute a recording mock.
protocol EventPosting: Sendable {
    /// Posts one click of `type` at `point`, in CG global space (top-left origin of the main display).
    ///
    /// A `.double` click posts both down/up pairs in a single call.
    func post(_ type: ClickType, at point: CGPoint)
}
