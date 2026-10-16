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
    }

    /// Generous enough for any real display arrangement, small enough that the value always fits in an `Int`.
    static let coordinateRange = -100_000...100_000

    /// The edited target.
    private(set) var target: ClickTarget
    /// The point used when switching from the cursor to a fixed position, so a previously used point comes back.
    let fallbackPoint: CGPoint

    init(target: ClickTarget, fallbackPoint: CGPoint = .zero) {
        self.target = target
        self.fallbackPoint = fallbackPoint
    }

    var kind: Kind {
        get {
            switch target {
            case .currentCursor: .currentCursor
            case .fixed: .fixed
            }
        }
        set {
            guard newValue != kind else { return }
            switch newValue {
            case .currentCursor:
                target = .currentCursor
            case .fixed:
                target = .fixed(fallbackPoint)
            }
        }
    }

    /// The fixed X coordinate, rounded to whole points, or zero while the cursor is the target.
    var x: Int {
        get { Self.wholePoints(fixedPoint?.x ?? 0) }
        set {
            guard let point = fixedPoint else { return }
            target = .fixed(CGPoint(x: CGFloat(newValue.clamped(to: Self.coordinateRange)), y: point.y))
        }
    }

    /// The fixed Y coordinate, rounded to whole points, or zero while the cursor is the target.
    var y: Int {
        get { Self.wholePoints(fixedPoint?.y ?? 0) }
        set {
            guard let point = fixedPoint else { return }
            target = .fixed(CGPoint(x: point.x, y: CGFloat(newValue.clamped(to: Self.coordinateRange))))
        }
    }

    private var fixedPoint: CGPoint? {
        guard case .fixed(let point) = target else { return nil }
        return point
    }

    /// Converts without trapping: `Int(_:)` crashes on non-finite or huge values, which corrupt settings could hold.
    private static func wholePoints(_ value: CGFloat) -> Int {
        guard value.isFinite else { return 0 }
        let bounds = CGFloat(coordinateRange.lowerBound)...CGFloat(coordinateRange.upperBound)
        return Int(value.rounded().clamped(to: bounds))
    }
}
