import CoreGraphics

/// Posts real mouse clicks through Core Graphics. Requires Accessibility permission to have any effect.
///
/// Events come from a `.hidSystemState` source and go to `.cghidEventTap`, so they look like hardware input to every
/// app. The source is created per post rather than stored: `CGEventSource` is not `Sendable`, and creating one is cheap
/// compared with posting, so this keeps the type trivially thread-safe without `@unchecked Sendable`.
final class CGEventPoster: EventPosting {
    /// Creates a poster. Creating one posts nothing.
    init() {}

    func post(_ type: ClickType, at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        for event in Self.makeEvents(for: type, at: point, source: source) {
            event.post(tap: .cghidEventTap)
        }
    }

    /// Builds, without posting, the events that make up one click of `type` at `point`.
    ///
    /// Left, right and middle produce one down/up pair with click state 1. Double produces two left pairs; the second
    /// carries click state 2, which the system needs to recognize a double click. Middle uses `.otherMouse*` events
    /// with the center button.
    ///
    /// Returns an empty array if any event cannot be created: posting a down without its matching up would leave the
    /// button stuck.
    static func makeEvents(for type: ClickType, at point: CGPoint, source: CGEventSource?) -> [CGEvent] {
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
                events.append(event)
            }
        }
        return events
    }
}
