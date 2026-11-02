import CoreGraphics

/// Editing glue between the Edit Points sheet and a sequence's point list (SPEC §7.2).
///
/// Every edit clamps: coordinates to `ClickTargetEditor.coordinateRange`, delays to `ClickPoint.delayRange` and the
/// list to `ClickTarget.maxSequencePoints`. Index-based edits ignore an index that is out of range, because a row's
/// control can still fire once after its point was removed.
struct ClickSequenceEditor: Equatable {
    /// The edited points, in click order.
    private(set) var points: [ClickPoint]

    init(points: [ClickPoint]) {
        self.points = Array(points.prefix(ClickTarget.maxSequencePoints))
    }

    /// The delay a new point gets: the interval's effective duration in milliseconds, clamped to
    /// `ClickPoint.delayRange`.
    static func defaultDelayMilliseconds(for interval: ClickInterval) -> Int {
        // `duration` is never below 1 ms; the interval's components allow up to 999 h, which exceeds the 24 h limit.
        max(interval.totalMilliseconds, ClickInterval.minimumMilliseconds).clamped(to: ClickPoint.delayRange)
    }

    /// Whether another point fits.
    var canAddPoint: Bool {
        points.count < ClickTarget.maxSequencePoints
    }

    /// Appends a point after the last one. Does nothing when the sequence is full.
    mutating func append(_ point: CGPoint, delayMilliseconds: Int) {
        guard canAddPoint else { return }
        let bounds =
            CGFloat(
                ClickTargetEditor.coordinateRange.lowerBound)...CGFloat(
                ClickTargetEditor.coordinateRange.upperBound)
        let clampedPoint = CGPoint(
            x: point.x.isFinite ? point.x.clamped(to: bounds) : 0,
            y: point.y.isFinite ? point.y.clamped(to: bounds) : 0)
        points.append(
            ClickPoint(point: clampedPoint, delayMilliseconds: delayMilliseconds.clamped(to: ClickPoint.delayRange)))
    }

    /// Removes the point at `index`.
    mutating func remove(at index: Int) {
        guard points.indices.contains(index) else { return }
        points.remove(at: index)
    }

    /// Whether the point at `index` can move one place earlier.
    func canMoveUp(at index: Int) -> Bool {
        points.indices.contains(index) && index > points.startIndex
    }

    /// Whether the point at `index` can move one place later.
    func canMoveDown(at index: Int) -> Bool {
        points.indices.contains(index) && index < points.index(before: points.endIndex)
    }

    /// Swaps the point at `index` with the one before it.
    mutating func moveUp(at index: Int) {
        guard canMoveUp(at: index) else { return }
        points.swapAt(index, index - 1)
    }

    /// Swaps the point at `index` with the one after it.
    mutating func moveDown(at index: Int) {
        guard canMoveDown(at: index) else { return }
        points.swapAt(index, index + 1)
    }

    /// The X coordinate of the point at `index` in whole points, or zero for an index out of range.
    func x(at index: Int) -> Int {
        guard points.indices.contains(index) else { return 0 }
        return ClickTargetEditor.wholePoints(points[index].point.x)
    }

    /// The Y coordinate of the point at `index` in whole points, or zero for an index out of range.
    func y(at index: Int) -> Int {
        guard points.indices.contains(index) else { return 0 }
        return ClickTargetEditor.wholePoints(points[index].point.y)
    }

    /// The delay of the point at `index` in milliseconds, inside `ClickPoint.delayRange`, or the minimum for an index
    /// out of range.
    func delayMilliseconds(at index: Int) -> Int {
        guard points.indices.contains(index) else { return ClickPoint.delayRange.lowerBound }
        return points[index].delayMilliseconds.clamped(to: ClickPoint.delayRange)
    }

    mutating func setX(_ x: Int, at index: Int) {
        guard points.indices.contains(index) else { return }
        points[index].point.x = CGFloat(x.clamped(to: ClickTargetEditor.coordinateRange))
    }

    mutating func setY(_ y: Int, at index: Int) {
        guard points.indices.contains(index) else { return }
        points[index].point.y = CGFloat(y.clamped(to: ClickTargetEditor.coordinateRange))
    }

    mutating func setDelayMilliseconds(_ delay: Int, at index: Int) {
        guard points.indices.contains(index) else { return }
        points[index].delayMilliseconds = delay.clamped(to: ClickPoint.delayRange)
    }
}
