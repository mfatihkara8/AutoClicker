import CoreGraphics
import Testing

@testable import AutoClicker

struct ClickTargetMemoryTests {
    private static let points = [ClickPoint(point: CGPoint(x: 1, y: 2), delayMilliseconds: 10)]

    @Test func startsAtTheOriginWithoutPoints() {
        let memory = ClickTargetMemory()
        #expect(memory.fixedPoint == .zero)
        #expect(memory.sequencePoints.isEmpty)
    }

    @Test func remembersAFixedPoint() {
        let memory = ClickTargetMemory().remembering(.fixed(CGPoint(x: 10, y: 20)))
        #expect(memory.fixedPoint == CGPoint(x: 10, y: 20))
        #expect(memory.sequencePoints.isEmpty)
    }

    @Test func remembersASequenceWithoutForgettingTheFixedPoint() {
        let memory = ClickTargetMemory()
            .remembering(.fixed(CGPoint(x: 10, y: 20)))
            .remembering(.sequence(Self.points))
        #expect(memory.fixedPoint == CGPoint(x: 10, y: 20))
        #expect(memory.sequencePoints == Self.points)
    }

    @Test func theCursorChangesNothing() {
        let memory = ClickTargetMemory(fixedPoint: CGPoint(x: 1, y: 1), sequencePoints: Self.points)
        #expect(memory.remembering(.currentCursor) == memory)
    }

    @Test func anEmptySequenceIsRememberedToo() {
        let memory = ClickTargetMemory(sequencePoints: Self.points).remembering(.sequence([]))
        #expect(memory.sequencePoints.isEmpty)
    }
}
