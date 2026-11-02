import CoreGraphics
import Testing

@testable import AutoClicker

struct ClickTargetEditorTests {
    @Test func readsTheKind() {
        #expect(ClickTargetEditor(target: .currentCursor).kind == .currentCursor)
        #expect(ClickTargetEditor(target: .fixed(CGPoint(x: 1, y: 2))).kind == .fixed)
    }

    @Test func switchingToFixedUsesTheFallbackPoint() {
        var editor = ClickTargetEditor(target: .currentCursor, fallbackPoint: CGPoint(x: 10, y: 20))
        editor.kind = .fixed
        #expect(editor.target == .fixed(CGPoint(x: 10, y: 20)))
    }

    @Test func switchingToFixedWithoutAFallbackUsesTheOrigin() {
        var editor = ClickTargetEditor(target: .currentCursor)
        editor.kind = .fixed
        #expect(editor.target == .fixed(.zero))
    }

    @Test func switchingToTheCursorDropsThePoint() {
        var editor = ClickTargetEditor(target: .fixed(CGPoint(x: 10, y: 20)))
        editor.kind = .currentCursor
        #expect(editor.target == .currentCursor)
    }

    @Test func selectingFixedAgainKeepsThePoint() {
        var editor = ClickTargetEditor(target: .fixed(CGPoint(x: 10, y: 20)), fallbackPoint: CGPoint(x: 1, y: 1))
        editor.kind = .fixed
        #expect(editor.target == .fixed(CGPoint(x: 10, y: 20)))
    }

    @Test func coordinatesAreRoundedToWholePoints() {
        let editor = ClickTargetEditor(target: .fixed(CGPoint(x: 10.6, y: -20.4)))
        #expect(editor.x == 11)
        #expect(editor.y == -20)
    }

    @Test func coordinatesReadZeroForTheCursor() {
        let editor = ClickTargetEditor(target: .currentCursor)
        #expect(editor.x == 0)
        #expect(editor.y == 0)
    }

    @Test func settingOneCoordinateKeepsTheOther() {
        var editor = ClickTargetEditor(target: .fixed(CGPoint(x: 10.5, y: 20.5)))
        editor.x = 100
        #expect(editor.target == .fixed(CGPoint(x: 100, y: 20.5)))
        editor.y = -50
        #expect(editor.target == .fixed(CGPoint(x: 100, y: -50)))
    }

    @Test func settingCoordinatesForTheCursorIsIgnored() {
        var editor = ClickTargetEditor(target: .currentCursor)
        editor.x = 5
        editor.y = 5
        #expect(editor.target == .currentCursor)
    }

    @Test func coordinatesAreClamped() {
        var editor = ClickTargetEditor(target: .fixed(.zero))
        editor.x = Int.max
        editor.y = Int.min
        let range = ClickTargetEditor.coordinateRange
        #expect(editor.target == .fixed(CGPoint(x: range.upperBound, y: range.lowerBound)))
    }

    @Test(arguments: [CGFloat.infinity, -CGFloat.infinity, CGFloat.nan, 1e300])
    func corruptCoordinatesDoNotTrap(value: CGFloat) {
        let editor = ClickTargetEditor(target: .fixed(CGPoint(x: value, y: value)))
        #expect(ClickTargetEditor.coordinateRange.contains(editor.x))
        #expect(ClickTargetEditor.coordinateRange.contains(editor.y))
    }

    @Test func readsTheSequenceKind() {
        let points = [ClickPoint(point: CGPoint(x: 1, y: 2), delayMilliseconds: 10)]
        let editor = ClickTargetEditor(target: .sequence(points))
        #expect(editor.kind == .sequence)
        #expect(editor.x == 0)
        #expect(editor.y == 0)
    }

    @Test func settingCoordinatesForASequenceIsIgnored() {
        let points = [ClickPoint(point: CGPoint(x: 1, y: 2), delayMilliseconds: 10)]
        var editor = ClickTargetEditor(target: .sequence(points))
        editor.x = 5
        editor.y = 5
        #expect(editor.target == .sequence(points))
    }

    @Test func switchingFromASequenceToFixedUsesTheFallbackPoint() {
        var editor = ClickTargetEditor(target: .sequence([]), fallbackPoint: CGPoint(x: 10, y: 20))
        editor.kind = .fixed
        #expect(editor.target == .fixed(CGPoint(x: 10, y: 20)))
    }
}
