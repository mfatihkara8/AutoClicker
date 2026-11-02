import CoreGraphics
import Testing

@testable import AutoClicker

struct ClickSequenceEditorTests {
    private static let a = ClickPoint(point: CGPoint(x: 10, y: 20), delayMilliseconds: 100)
    private static let b = ClickPoint(point: CGPoint(x: 30, y: 40), delayMilliseconds: 200)
    private static let c = ClickPoint(point: CGPoint(x: 50, y: 60), delayMilliseconds: 300)

    private static func full() -> ClickSequenceEditor {
        ClickSequenceEditor(points: Array(repeating: a, count: ClickTarget.maxSequencePoints))
    }

    // MARK: - Init and default delay

    @Test func initKeepsAtMostTheMaximumPoints() {
        let editor = ClickSequenceEditor(points: Array(repeating: Self.a, count: ClickTarget.maxSequencePoints + 1))
        #expect(editor.points.count == ClickTarget.maxSequencePoints)
    }

    @Test(arguments: [
        (ClickInterval(milliseconds: 100), 100),
        (ClickInterval(seconds: 1, milliseconds: 500), 1_500),
        (ClickInterval(), 1),
        (ClickInterval(hours: 25), ClickPoint.delayRange.upperBound),
        (ClickInterval(hours: 999, minutes: 59, seconds: 59, milliseconds: 999), ClickPoint.delayRange.upperBound),
    ])
    func defaultDelayIsTheIntervalClampedToTheDelayRange(interval: ClickInterval, expected: Int) {
        #expect(ClickSequenceEditor.defaultDelayMilliseconds(for: interval) == expected)
    }

    @Test func defaultDelayIgnoresJitter() {
        let interval = ClickInterval(milliseconds: 100, jitterMilliseconds: 40)
        #expect(ClickSequenceEditor.defaultDelayMilliseconds(for: interval) == 100)
    }

    // MARK: - Add

    @Test func appendAddsAfterTheLastPoint() {
        var editor = ClickSequenceEditor(points: [Self.a])
        editor.append(CGPoint(x: 30, y: 40), delayMilliseconds: 200)
        #expect(editor.points == [Self.a, Self.b])
    }

    @Test func appendClampsTheDelay() {
        var editor = ClickSequenceEditor(points: [])
        editor.append(.zero, delayMilliseconds: 0)
        editor.append(.zero, delayMilliseconds: Int.max)
        #expect(editor.points.map(\.delayMilliseconds) == [1, ClickPoint.delayRange.upperBound])
    }

    @Test func appendClampsCorruptCoordinates() {
        var editor = ClickSequenceEditor(points: [])
        editor.append(CGPoint(x: 1e12, y: CGFloat.nan), delayMilliseconds: 10)
        let range = ClickTargetEditor.coordinateRange
        #expect(editor.points == [ClickPoint(point: CGPoint(x: range.upperBound, y: 0), delayMilliseconds: 10)])
    }

    @Test func appendKeepsFractionalCoordinatesLikePickLocation() {
        var editor = ClickSequenceEditor(points: [])
        editor.append(CGPoint(x: 10.5, y: -3.25), delayMilliseconds: 10)
        #expect(editor.points.first?.point == CGPoint(x: 10.5, y: -3.25))
    }

    @Test func aFullSequenceAcceptsNoMorePoints() {
        var editor = Self.full()
        #expect(editor.canAddPoint == false)
        editor.append(.zero, delayMilliseconds: 1)
        #expect(editor.points.count == ClickTarget.maxSequencePoints)
    }

    @Test func oneBelowTheMaximumAcceptsOneMorePoint() {
        var editor = ClickSequenceEditor(points: Array(repeating: Self.a, count: ClickTarget.maxSequencePoints - 1))
        #expect(editor.canAddPoint)
        editor.append(.zero, delayMilliseconds: 1)
        #expect(editor.canAddPoint == false)
    }

    // MARK: - Remove and move

    @Test func removeDropsOnlyThatPoint() {
        var editor = ClickSequenceEditor(points: [Self.a, Self.b, Self.c])
        editor.remove(at: 1)
        #expect(editor.points == [Self.a, Self.c])
    }

    @Test(arguments: [-1, 3, Int.max])
    func editsAtAnIndexOutOfRangeAreIgnored(index: Int) {
        var editor = ClickSequenceEditor(points: [Self.a, Self.b, Self.c])
        editor.remove(at: index)
        editor.moveUp(at: index)
        editor.moveDown(at: index)
        editor.setX(1, at: index)
        editor.setY(1, at: index)
        editor.setDelayMilliseconds(1, at: index)
        #expect(editor.points == [Self.a, Self.b, Self.c])
        #expect(editor.x(at: index) == 0)
        #expect(editor.y(at: index) == 0)
        #expect(editor.delayMilliseconds(at: index) == ClickPoint.delayRange.lowerBound)
        #expect(editor.canMoveUp(at: index) == false)
        #expect(editor.canMoveDown(at: index) == false)
    }

    @Test func moveUpSwapsWithThePreviousPoint() {
        var editor = ClickSequenceEditor(points: [Self.a, Self.b, Self.c])
        editor.moveUp(at: 2)
        #expect(editor.points == [Self.a, Self.c, Self.b])
    }

    @Test func moveDownSwapsWithTheNextPoint() {
        var editor = ClickSequenceEditor(points: [Self.a, Self.b, Self.c])
        editor.moveDown(at: 0)
        #expect(editor.points == [Self.b, Self.a, Self.c])
    }

    @Test func theFirstPointCannotMoveUpAndTheLastCannotMoveDown() {
        var editor = ClickSequenceEditor(points: [Self.a, Self.b, Self.c])
        #expect(editor.canMoveUp(at: 0) == false)
        #expect(editor.canMoveUp(at: 1))
        #expect(editor.canMoveDown(at: 1))
        #expect(editor.canMoveDown(at: 2) == false)

        editor.moveUp(at: 0)
        editor.moveDown(at: 2)
        #expect(editor.points == [Self.a, Self.b, Self.c])
    }

    @Test func aSinglePointCannotMove() {
        let editor = ClickSequenceEditor(points: [Self.a])
        #expect(editor.canMoveUp(at: 0) == false)
        #expect(editor.canMoveDown(at: 0) == false)
    }

    // MARK: - Edit

    @Test func readsWholePointsAndTheDelay() {
        let editor = ClickSequenceEditor(
            points: [ClickPoint(point: CGPoint(x: 10.6, y: -20.4), delayMilliseconds: 250)])
        #expect(editor.x(at: 0) == 11)
        #expect(editor.y(at: 0) == -20)
        #expect(editor.delayMilliseconds(at: 0) == 250)
    }

    @Test func readsAStoredDelayOutsideTheRangeClamped() {
        let editor = ClickSequenceEditor(points: [ClickPoint(point: .zero, delayMilliseconds: -5)])
        #expect(editor.delayMilliseconds(at: 0) == ClickPoint.delayRange.lowerBound)
    }

    @Test func editingOneValueKeepsTheOthers() {
        var editor = ClickSequenceEditor(points: [Self.a, Self.b])
        editor.setX(-1920, at: 1)
        editor.setY(5, at: 1)
        editor.setDelayMilliseconds(750, at: 1)
        #expect(editor.points == [Self.a, ClickPoint(point: CGPoint(x: -1920, y: 5), delayMilliseconds: 750)])
    }

    @Test func editsAreClamped() {
        var editor = ClickSequenceEditor(points: [Self.a])
        editor.setX(Int.max, at: 0)
        editor.setY(Int.min, at: 0)
        editor.setDelayMilliseconds(0, at: 0)
        let range = ClickTargetEditor.coordinateRange
        #expect(
            editor.points == [
                ClickPoint(point: CGPoint(x: range.upperBound, y: range.lowerBound), delayMilliseconds: 1)
            ])

        editor.setDelayMilliseconds(Int.max, at: 0)
        #expect(editor.points.first?.delayMilliseconds == ClickPoint.delayRange.upperBound)
    }
}
