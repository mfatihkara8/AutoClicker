import CoreGraphics
import Testing

@testable import AutoClicker

/// Exercises the pure event builder only. `CGEventPoster.post` is never called, so no real event is posted.
struct CGEventPosterTests {
    private let point = CGPoint(x: 321.5, y: 87)

    /// The four modifier flags, the only ones a click may carry (ADR-009).
    private static let modifierFlags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    /// Every modifier on its own and every combination of them, all 16 sets.
    private static let everyModifierSet: [ClickModifiers] = (0..<16).map { ClickModifiers(rawValue: $0) }

    private func events(_ type: ClickType, modifiers: ClickModifiers = []) -> [CGEvent] {
        CGEventPoster.makeEvents(for: type, at: point, modifiers: modifiers, source: nil)
    }

    // MARK: - Shape

    @Test func leftClickIsOneLeftDownUpPair() {
        let events = events(.left)
        #expect(events.map(\.type) == [.leftMouseDown, .leftMouseUp])
        #expect(events.map(clickState) == [1, 1])
        #expect(events.map(buttonNumber) == [Int64(CGMouseButton.left.rawValue), Int64(CGMouseButton.left.rawValue)])
    }

    @Test func rightClickIsOneRightDownUpPair() {
        let events = events(.right)
        #expect(events.map(\.type) == [.rightMouseDown, .rightMouseUp])
        #expect(events.map(clickState) == [1, 1])
        #expect(
            events.map(buttonNumber) == [Int64(CGMouseButton.right.rawValue), Int64(CGMouseButton.right.rawValue)])
    }

    @Test func middleClickUsesOtherMouseEventsWithTheCenterButton() {
        let events = events(.middle)
        #expect(events.map(\.type) == [.otherMouseDown, .otherMouseUp])
        #expect(events.map(clickState) == [1, 1])
        #expect(
            events.map(buttonNumber) == [Int64(CGMouseButton.center.rawValue), Int64(CGMouseButton.center.rawValue)])
    }

    @Test func doubleClickIsTwoLeftPairsWithClickStatesOneThenTwo() {
        let events = events(.double)
        #expect(events.map(\.type) == [.leftMouseDown, .leftMouseUp, .leftMouseDown, .leftMouseUp])
        #expect(events.map(clickState) == [1, 1, 2, 2])
    }

    @Test(arguments: ClickType.allCases)
    func everyEventIsPlacedAtTheTargetPoint(type: ClickType) {
        let events = events(type)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.location == point })
    }

    @Test(arguments: ClickType.allCases, everyModifierSet)
    func modifiersDoNotChangeTheEventShape(type: ClickType, modifiers: ClickModifiers) {
        let plain = events(type)
        let modified = events(type, modifiers: modifiers)
        #expect(modified.map(\.type) == plain.map(\.type))
        #expect(modified.map(clickState) == plain.map(clickState))
        #expect(modified.map(buttonNumber) == plain.map(buttonNumber))
        #expect(modified.allSatisfy { $0.location == point })
    }

    @Test func eventsBuiltFromAHIDSystemStateSourceKeepTheSameShape() throws {
        // Creating a source and events does not post anything; only `CGEvent.post(tap:)` would.
        let source = try #require(CGEventSource(stateID: .hidSystemState))
        let events = CGEventPoster.makeEvents(for: .double, at: point, modifiers: [], source: source)
        #expect(events.count == 4)
    }

    // MARK: - Modifier flags

    @Test func eachModifierMapsToItsOwnFlag() {
        #expect(CGEventPoster.flags(for: .shift) == .maskShift)
        #expect(CGEventPoster.flags(for: .control) == .maskControl)
        #expect(CGEventPoster.flags(for: .option) == .maskAlternate)
        #expect(CGEventPoster.flags(for: .command) == .maskCommand)
    }

    @Test func combinedModifiersMapToTheUnionOfTheirFlags() {
        #expect(CGEventPoster.flags(for: [.shift, .command]) == [.maskShift, .maskCommand])
        #expect(CGEventPoster.flags(for: [.control, .option]) == [.maskControl, .maskAlternate])
        #expect(CGEventPoster.flags(for: [.shift, .control, .option, .command]) == Self.modifierFlags)
    }

    @Test func noModifiersMapToEmptyFlags() {
        #expect(CGEventPoster.flags(for: []).rawValue == 0)
    }

    @Test(arguments: ClickType.allCases, everyModifierSet)
    func everyEventCarriesExactlyTheExpectedFlags(type: ClickType, modifiers: ClickModifiers) {
        let events = events(type, modifiers: modifiers)
        let expected = expectedFlags(for: modifiers)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.flags.rawValue == expected.rawValue })
    }

    @Test(arguments: ClickType.allCases)
    func noModifiersGiveEmptyFlagsOnEveryEvent(type: ClickType) {
        let events = events(type)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.flags.rawValue == 0 })
    }

    @Test(arguments: ClickType.allCases)
    func noModifiersClearFlagsFromAHIDSystemStateSource(type: ClickType) throws {
        // The source starts each event with the live modifier state; a plain click must still carry no flags.
        let source = try #require(CGEventSource(stateID: .hidSystemState))
        let events = CGEventPoster.makeEvents(for: type, at: point, modifiers: [], source: source)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.flags.rawValue == 0 })
    }

    @Test(arguments: ClickType.allCases)
    func modifiersFromAHIDSystemStateSourceAreExact(type: ClickType) throws {
        let source = try #require(CGEventSource(stateID: .hidSystemState))
        let events = CGEventPoster.makeEvents(for: type, at: point, modifiers: [.shift, .command], source: source)
        #expect(!events.isEmpty)
        let expected: CGEventFlags = [.maskShift, .maskCommand]
        #expect(events.allSatisfy { $0.flags.rawValue == expected.rawValue })
    }

    @Test(arguments: ClickType.allCases)
    func onlyMouseEventsArePostedNeverKeyEvents(type: ClickType) {
        let mouseTypes: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
        ]
        let events = events(type, modifiers: [.shift, .control, .option, .command])
        #expect(events.allSatisfy { mouseTypes.contains($0.type) })
    }

    // MARK: - Helpers

    /// Built independently of `CGEventPoster.flags(for:)`, so the event test does not just mirror the implementation.
    private func expectedFlags(for modifiers: ClickModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.shift) { flags.formUnion(.maskShift) }
        if modifiers.contains(.control) { flags.formUnion(.maskControl) }
        if modifiers.contains(.option) { flags.formUnion(.maskAlternate) }
        if modifiers.contains(.command) { flags.formUnion(.maskCommand) }
        return flags
    }

    private func clickState(_ event: CGEvent) -> Int64 {
        event.getIntegerValueField(.mouseEventClickState)
    }

    private func buttonNumber(_ event: CGEvent) -> Int64 {
        event.getIntegerValueField(.mouseEventButtonNumber)
    }
}
