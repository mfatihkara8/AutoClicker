import CoreGraphics

/// The last fixed point and the last point list seen this session, so switching between Cursor, Fixed and Sequence
/// brings each mode's values back (SPEC §7.2).
///
/// It is not persisted: only the current target is part of the settings.
struct ClickTargetMemory: Equatable {
    /// The last fixed point, used when switching to Fixed.
    var fixedPoint: CGPoint = .zero
    /// The last point list, used when switching to Sequence. It may be empty.
    var sequencePoints: [ClickPoint] = []

    /// Records the values of `target`. The cursor has no values, so it leaves the memory unchanged.
    mutating func remember(_ target: ClickTarget) {
        switch target {
        case .currentCursor:
            break
        case .fixed(let point):
            fixedPoint = point
        case .sequence(let points):
            sequencePoints = points
        }
    }

    /// Returns a copy that has recorded the values of `target`.
    func remembering(_ target: ClickTarget) -> ClickTargetMemory {
        var memory = self
        memory.remember(target)
        return memory
    }
}
