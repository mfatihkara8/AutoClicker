@testable import AutoClicker

/// A `HotkeyProviding` implementation that records registrations instead of touching Carbon.
///
/// `simulatePress(_:)` stands in for the user pressing a key, so tests can drive the F6 toggle and
/// the scoped ESC stop without registering real hotkeys.
@MainActor
final class MockHotkeyProvider: HotkeyProviding {
    private var handlers: [Hotkey: @MainActor () -> Void] = [:]

    /// Every hotkey passed to `register(_:handler:)`, in call order, including failed attempts.
    private(set) var registerCalls: [Hotkey] = []
    /// Every hotkey passed to `unregister(_:)`, in call order.
    private(set) var unregisterCalls: [Hotkey] = []
    private(set) var unregisterAllCallCount = 0

    /// Errors to throw from `register(_:handler:)`, keyed by hotkey, to test failure paths.
    var registrationErrors: [Hotkey: HotkeyRegistrationError] = [:]

    var registeredHotkeys: Set<Hotkey> {
        Set(handlers.keys)
    }

    func register(_ hotkey: Hotkey, handler: @escaping @MainActor () -> Void) throws {
        registerCalls.append(hotkey)
        if let error = registrationErrors[hotkey] {
            throw error
        }
        handlers[hotkey] = handler
    }

    func unregister(_ hotkey: Hotkey) {
        unregisterCalls.append(hotkey)
        handlers[hotkey] = nil
    }

    func unregisterAll() {
        unregisterAllCallCount += 1
        handlers.removeAll()
    }

    func isRegistered(_ hotkey: Hotkey) -> Bool {
        handlers[hotkey] != nil
    }

    /// Calls the handler of `hotkey` as if the user pressed it.
    ///
    /// - Returns: `false` when `hotkey` is not registered, mirroring the system, which delivers nothing.
    @discardableResult
    func simulatePress(_ hotkey: Hotkey) -> Bool {
        guard let handler = handlers[hotkey] else { return false }
        handler()
        return true
    }
}
