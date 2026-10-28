import CoreGraphics

/// Posts real mouse clicks through Core Graphics. Requires Accessibility permission to have any effect.
///
/// Events come from a `.hidSystemState` source and go to `.cghidEventTap`, so they look like hardware input to every
/// app. The source is created per post rather than stored: `CGEventSource` is not `Sendable`, and creating one is cheap
/// compared with posting, so this keeps the type trivially thread-safe without `@unchecked Sendable`.
final class CGEventPoster: EventPosting {
    /// Creates a poster. Creating one posts nothing.
    init() {}

    func post(_ type: ClickType, at point: CGPoint, modifiers: ClickModifiers) {
        let source = CGEventSource(stateID: .hidSystemState)
        for event in Self.makeEvents(for: type, at: point, modifiers: modifiers, source: source) {
            event.post(tap: .cghidEventTap)
        }
    }

    /// Builds, without posting, the events that make up one click of `type` at `point` with `modifiers` held.
    ///
    /// Left, right and middle produce one down/up pair with click state 1. Double produces two left pairs; the second
    /// carries click state 2, which the system needs to recognize a double click. Middle uses `.otherMouse*` events
    /// with the center button.
    ///
    /// Every event's flags are set to exactly `flags(for: modifiers)`, also when `modifiers` is empty (ADR-009). An
    /// event created from a `.hidSystemState` source starts with that source's current modifier state, so keys the
    /// user physically holds (or Caps Lock) would otherwise leak into a plain click. Assigning `flags` replaces them
    /// rather than adding to them.
    ///
    /// Returns an empty array if any event cannot be created: posting a down without its matching up would leave the
    /// button stuck.
    static func makeEvents(
        for type: ClickType, at point: CGPoint, modifiers: ClickModifiers, source: CGEventSource?
    ) -> [CGEvent] {
        let eventFlags = flags(for: modifiers)
        let pairs: [(down: CGEventType, up: CGEventType, button: CGMouseButton, clickState: Int64)]
        switch type {
        case .left:
            pairs = [(.leftMouseDown, .leftMouseUp, .left, 1)]
        case .right:
            pairs = [(.rightMouseDown, .rightMouseUp, .right, 1)]
        case .middle:
            pairs = [(.otherMouseDown, .otherMouseUp, .center, 1)]
        case .double:
            pairs = [
                (.leftMouseDown, .leftMouseUp, .left, 1),
                (.leftMouseDown, .leftMouseUp, .left, 2),
            ]
        }

        var events: [CGEvent] = []
        events.reserveCapacity(pairs.count * 2)
        for pair in pairs {
            for eventType in [pair.down, pair.up] {
                guard
                    let event = CGEvent(
                        mouseEventSource: source, mouseType: eventType, mouseCursorPosition: point,
                        mouseButton: pair.button)
                else {
                    return []
                }
                event.setIntegerValueField(.mouseEventClickState, value: pair.clickState)
                event.flags = eventFlags
                events.append(event)
            }
        }
        return events
    }

    /// The `CGEventFlags` that mark `modifiers` as held on a mouse event, and nothing else.
    static func flags(for modifiers: ClickModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        return flags
    }
}
