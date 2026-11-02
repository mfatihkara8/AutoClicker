import CoreGraphics
import Testing

@testable import AutoClicker

struct ClickTargetEditorTests {
    @Test func readsTheKind() {
        #expect(ClickTargetEditor(target: .currentCursor).kind == .currentCursor)
        #expect(ClickTargetEditor(target: .fixed(CGPoint(x: 1, y: 2))).kind == .fixed)
    }

    @Test func switchingToFixedUsesTheRememberedPoint() {
        var editor = ClickTargetEditor(
            target: .currentCursor, memory: ClickTargetMemory(fixedPoint: CGPoint(x: 10, y: 20)))
        editor.kind = .fixed
        #expect(editor.target == .fixed(CGPoint(x: 10, y: 20)))
    }

    @Test func switchingToFixedWithoutAMemoryUsesTheOrigin() {
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
        var editor = ClickTargetEditor(
            target: .fixed(CGPoint(x: 10, y: 20)), memory: ClickTargetMemory(fixedPoint: CGPoint(x: 1, y: 1)))
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

    @Test func switchingFromASequenceToFixedUsesTheRememberedPoint() {
        var editor = ClickTargetEditor(
            target: .sequence([]), memory: ClickTargetMemory(fixedPoint: CGPoint(x: 10, y: 20)))
        editor.kind = .fixed
        #expect(editor.target == .fixed(CGPoint(x: 10, y: 20)))
    }

    // MARK: - Sequence (T-1201)

    private static let points = [
        ClickPoint(point: CGPoint(x: 1, y: 2), delayMilliseconds: 10),
        ClickPoint(point: CGPoint(x: 3, y: 4), delayMilliseconds: 20),
    ]

    @Test func switchingToASequenceBringsBackTheRememberedPoints() {
        var editor = ClickTargetEditor(
            target: .fixed(CGPoint(x: 5, y: 5)), memory: ClickTargetMemory(sequencePoints: Self.points))
        editor.kind = .sequence
        #expect(editor.target == .sequence(Self.points))
    }

    @Test func switchingToASequenceWithoutAMemoryStartsEmpty() {
        var editor = ClickTargetEditor(target: .currentCursor)
        editor.kind = .sequence
        #expect(editor.target == .sequence([]))
    }

    @Test func switchingToASequenceKeepsAtMostTheMaximumPoints() {
        let many = Array(repeating: Self.points[0], count: ClickTarget.maxSequencePoints + 5)
        var editor = ClickTargetEditor(target: .currentCursor, memory: ClickTargetMemory(sequencePoints: many))
        editor.kind = .sequence
        #expect(editor.sequencePoints.count == ClickTarget.maxSequencePoints)
    }

    /// Switches `target` to `kind` the way the Target section does: the memory has seen every earlier target.
    private func switching(
        _ target: ClickTarget, to kind: ClickTargetEditor.Kind, memory: inout ClickTargetMemory
    ) -> ClickTarget {
        memory.remember(target)
        var editor = ClickTargetEditor(target: target, memory: memory)
        editor.kind = kind
        return editor.target
    }

    @Test func switchingThroughEveryKindKeepsEachModesValues() {
        let fixed = CGPoint(x: 640, y: 400)
        var memory = ClickTargetMemory()

        var target = switching(.fixed(fixed), to: .sequence, memory: &memory)
        #expect(target == .sequence([]))
        var editor = ClickTargetEditor(target: target, memory: memory)
        editor.sequencePoints = Self.points
        target = switching(editor.target, to: .currentCursor, memory: &memory)
        #expect(target == .currentCursor)
        target = switching(target, to: .fixed, memory: &memory)
        #expect(target == .fixed(fixed))
        target = switching(target, to: .sequence, memory: &memory)
        #expect(target == .sequence(Self.points))
    }

    @Test func sequencePointsAreEmptyForOtherKinds() {
        #expect(ClickTargetEditor(target: .currentCursor).sequencePoints.isEmpty)
        #expect(ClickTargetEditor(target: .fixed(.zero)).sequencePoints.isEmpty)
        #expect(ClickTargetEditor(target: .sequence(Self.points)).sequencePoints == Self.points)
    }

    @Test func settingSequencePointsReplacesThem() {
        var editor = ClickTargetEditor(target: .sequence([]))
        editor.sequencePoints = Self.points
        #expect(editor.target == .sequence(Self.points))
    }

    @Test func settingSequencePointsForOtherKindsIsIgnored() {
        var editor = ClickTargetEditor(target: .fixed(CGPoint(x: 5, y: 5)))
        editor.sequencePoints = Self.points
        #expect(editor.target == .fixed(CGPoint(x: 5, y: 5)))
    }

    @Test func settingTooManySequencePointsKeepsTheFirstOnes() {
        let many = (0..<(ClickTarget.maxSequencePoints + 3)).map {
            ClickPoint(point: CGPoint(x: $0, y: 0), delayMilliseconds: 1)
        }
        var editor = ClickTargetEditor(target: .sequence([]))
        editor.sequencePoints = many
        #expect(editor.sequencePoints == Array(many.prefix(ClickTarget.maxSequencePoints)))
    }
}
