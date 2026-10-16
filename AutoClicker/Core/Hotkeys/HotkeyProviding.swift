/// Registers system-wide hotkeys and calls a handler when one is pressed.
///
/// The production implementation is `CarbonHotkeyManager`; tests use `MockHotkeyProvider`.
/// Individual hotkeys can be registered and unregistered at any time, which the scoped ESC
/// emergency stop relies on (SPEC §3.4).
@MainActor
protocol HotkeyProviding: AnyObject {
    /// Registers `hotkey` and calls `handler` on the main actor every time it is pressed.
    ///
    /// Registering a hotkey that is already registered replaces its handler and keeps the existing
    /// system registration, so calling this twice is safe and never throws for that reason.
    /// The provider keeps `handler` until the hotkey is unregistered, so capture `[weak self]` in it.
    ///
    /// - Throws: `HotkeyRegistrationError` when the system refuses the registration.
    func register(_ hotkey: Hotkey, handler: @escaping @MainActor () -> Void) throws

    /// Unregisters `hotkey` and drops its handler. Does nothing if it is not registered.
    func unregister(_ hotkey: Hotkey)

    /// Unregisters every hotkey this provider registered.
    func unregisterAll()

    /// Whether `hotkey` is currently registered with this provider.
    func isRegistered(_ hotkey: Hotkey) -> Bool
}

/// Why a hotkey could not be registered. The associated `status` is the Carbon `OSStatus`.
enum HotkeyRegistrationError: Error, Equatable, Sendable {
    /// Installing the application-wide hot-key event handler failed.
    case eventHandlerInstallationFailed(status: Int32)
    /// `RegisterEventHotKey` rejected the hotkey, for example because another app already owns it.
    case registrationFailed(Hotkey, status: Int32)
}
