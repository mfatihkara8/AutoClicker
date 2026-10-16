import CoreGraphics
import Testing

@testable import AutoClicker

/// Exercises the pure event builder only. `CGEventPoster.post` is never called, so no real event is posted.
struct CGEventPosterTests {
    private let point = CGPoint(x: 321.5, y: 87)

    @Test func leftClickIsOneLeftDownUpPair() {
        let events = CGEventPoster.makeEvents(for: .left, at: point, source: nil)
        #expect(events.map(\.type) == [.leftMouseDown, .leftMouseUp])
        #expect(events.map(clickState) == [1, 1])
        #expect(events.map(buttonNumber) == [Int64(CGMouseButton.left.rawValue), Int64(CGMouseButton.left.rawValue)])
    }

    @Test func rightClickIsOneRightDownUpPair() {
        let events = CGEventPoster.makeEvents(for: .right, at: point, source: nil)
        #expect(events.map(\.type) == [.rightMouseDown, .rightMouseUp])
        #expect(events.map(clickState) == [1, 1])
        #expect(
            events.map(buttonNumber) == [Int64(CGMouseButton.right.rawValue), Int64(CGMouseButton.right.rawValue)])
    }

    @Test func middleClickUsesOtherMouseEventsWithTheCenterButton() {
        let events = CGEventPoster.makeEvents(for: .middle, at: point, source: nil)
        #expect(events.map(\.type) == [.otherMouseDown, .otherMouseUp])
        #expect(events.map(clickState) == [1, 1])
        #expect(
            events.map(buttonNumber) == [Int64(CGMouseButton.center.rawValue), Int64(CGMouseButton.center.rawValue)])
    }

    @Test func doubleClickIsTwoLeftPairsWithClickStatesOneThenTwo() {
        let events = CGEventPoster.makeEvents(for: .double, at: point, source: nil)
        #expect(events.map(\.type) == [.leftMouseDown, .leftMouseUp, .leftMouseDown, .leftMouseUp])
        #expect(events.map(clickState) == [1, 1, 2, 2])
    }

    @Test(arguments: ClickType.allCases)
    func everyEventIsPlacedAtTheTargetPoint(type: ClickType) {
        let events = CGEventPoster.makeEvents(for: type, at: point, source: nil)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.location == point })
    }

    @Test func eventsBuiltFromAHIDSystemStateSourceKeepTheSameShape() throws {
        // Creating a source and events does not post anything; only `CGEvent.post(tap:)` would.
        let source = try #require(CGEventSource(stateID: .hidSystemState))
        let events = CGEventPoster.makeEvents(for: .double, at: point, source: source)
        #expect(events.count == 4)
    }

    private func clickState(_ event: CGEvent) -> Int64 {
        event.getIntegerValueField(.mouseEventClickState)
    }

    private func buttonNumber(_ event: CGEvent) -> Int64 {
        event.getIntegerValueField(.mouseEventButtonNumber)
    }
}
