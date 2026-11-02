import CoreGraphics

/// Editing glue between the target card's controls and a `ClickTarget`.
///
/// X and Y are whole points in CG global space, as stored (ADR-006); no conversion happens here. They may be negative,
/// because displays left of or above the main display have negative CG coordinates.
struct ClickTargetEditor: Equatable {
    /// The kinds of target the card offers.
    enum Kind: CaseIterable, Hashable {
        case currentCursor
        case fixed
        case sequence
    }

    /// Generous enough for any real display arrangement, small enough that the value always fits in an `Int`.
    static let coordinateRange = -100_000...100_000

    /// The edited target.
    private(set) var target: ClickTarget
    /// The values used when switching kinds, so a previously used point or point list comes back.
    let memory: ClickTargetMemory

    init(target: ClickTarget, memory: ClickTargetMemory = ClickTargetMemory()) {
        self.target = target
        self.memory = memory
    }

    var kind: Kind {
        get {
            switch target {
            case .currentCursor: .currentCursor
            case .fixed: .fixed
            case .sequence: .sequence
            }
        }
        set {
            guard newValue != kind else { return }
            switch newValue {
            case .currentCursor:
                target = .currentCursor
            case .fixed:
                target = .fixed(memory.fixedPoint)
            case .sequence:
                target = .sequence(Array(memory.sequencePoints.prefix(ClickTarget.maxSequencePoints)))
            }
        }
    }

    /// The fixed X coordinate, rounded to whole points, or zero while the target is not a fixed point.
    var x: Int {
        get { Self.wholePoints(fixedPoint?.x ?? 0) }
        set {
            guard let point = fixedPoint else { return }
            target = .fixed(CGPoint(x: CGFloat(newValue.clamped(to: Self.coordinateRange)), y: point.y))
        }
    }

    /// The fixed Y coordinate, rounded to whole points, or zero while the target is not a fixed point.
    var y: Int {
        get { Self.wholePoints(fixedPoint?.y ?? 0) }
        set {
            guard let point = fixedPoint else { return }
            target = .fixed(CGPoint(x: point.x, y: CGFloat(newValue.clamped(to: Self.coordinateRange))))
        }
    }

    /// The sequence's points, or none while the target is not a sequence.
    ///
    /// Setting it is ignored unless the target is a sequence, so a stale editor (a sheet still open after a profile
    /// changed the target) cannot turn another target back into a sequence. At most `ClickTarget.maxSequencePoints`
    /// points are kept.
    var sequencePoints: [ClickPoint] {
        get {
            guard case .sequence(let points) = target else { return [] }
            return points
        }
        set {
            guard case .sequence = target else { return }
            target = .sequence(Array(newValue.prefix(ClickTarget.maxSequencePoints)))
        }
    }

    private var fixedPoint: CGPoint? {
        guard case .fixed(let point) = target else { return nil }
        return point
    }

    /// Converts without trapping: `Int(_:)` crashes on non-finite or huge values, which corrupt settings could hold.
    static func wholePoints(_ value: CGFloat) -> Int {
        guard value.isFinite else { return 0 }
        let bounds = CGFloat(coordinateRange.lowerBound)...CGFloat(coordinateRange.upperBound)
        return Int(value.rounded().clamped(to: bounds))
    }
}
