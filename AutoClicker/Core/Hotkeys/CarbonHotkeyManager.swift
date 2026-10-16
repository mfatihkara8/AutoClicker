import Carbon

/// Registers global hotkeys with Carbon's `RegisterEventHotKey` (ADR-002).
///
/// Carbon hotkeys need no Input Monitoring permission and cost no CPU while idle. Event taps and
/// `NSEvent` global monitors are deliberately not used.
///
/// One application-wide event handler is installed lazily on the first registration, so creating a
/// manager has no system side effects. Every hotkey gets a unique `EventHotKeyID`, and presses are
/// routed back to the matching handler. All hotkeys and the event handler are released in `deinit`.
@MainActor
final class CarbonHotkeyManager: HotkeyProviding {
    private struct Registration {
        let id: UInt32
        let ref: EventHotKeyRef
        var handler: @MainActor () -> Void
    }

    /// Tags our `EventHotKeyID`s so presses of hotkeys we did not register are ignored. Spells 'ACLK'.
    private static let signature: OSType = 0x4143_4C4B

    private var registrations: [Hotkey: Registration] = [:]
    private var hotkeysByID: [UInt32: Hotkey] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    init() {}

    // `isolated` keeps the Carbon calls on the main actor, where all other access to the refs happens.
    // The compiler back-deploys main-actor isolated deinit to macOS 14: it runs inline when the last
    // reference is dropped on the main thread (the normal case) and is enqueued on the main actor otherwise.
    isolated deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    /// Registers `hotkey` with `RegisterEventHotKey`. Re-registering replaces the handler only.
    func register(_ hotkey: Hotkey, handler: @escaping @MainActor () -> Void) throws {
        if registrations[hotkey] != nil {
            registrations[hotkey]?.handler = handler
            return
        }

        try installEventHandlerIfNeeded()

        let id = nextID
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            throw HotkeyRegistrationError.registrationFailed(hotkey, status: status)
        }

        nextID += 1
        registrations[hotkey] = Registration(id: id, ref: ref, handler: handler)
        hotkeysByID[id] = hotkey
    }

    /// Unregisters `hotkey` with `UnregisterEventHotKey`. Does nothing if it is not registered.
    func unregister(_ hotkey: Hotkey) {
        guard let registration = registrations.removeValue(forKey: hotkey) else { return }
        hotkeysByID[registration.id] = nil
        UnregisterEventHotKey(registration.ref)
    }

    /// Unregisters every hotkey. The event handler stays installed for later registrations.
    func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
        hotkeysByID.removeAll()
    }

    func isRegistered(_ hotkey: Hotkey) -> Bool {
        registrations[hotkey] != nil
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        // The C callback cannot capture context, so the manager travels through `userData` (ADR-002).
        // Unretained is safe because the handler is removed in `deinit`, before the manager is freed.
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handleHotkeyEvent,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard status == noErr, let handlerRef else {
            throw HotkeyRegistrationError.eventHandlerInstallationFailed(status: status)
        }
        eventHandler = handlerRef
    }

    fileprivate func handlePress(of hotkeyID: EventHotKeyID) -> OSStatus {
        guard hotkeyID.signature == Self.signature,
            let hotkey = hotkeysByID[hotkeyID.id],
            let handler = registrations[hotkey]?.handler
        else {
            return OSStatus(eventNotHandledErr)
        }
        handler()
        return noErr
    }
}

/// The Carbon event handler. A free function because Carbon needs a C function pointer.
private func handleHotkeyEvent(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else { return status }

    let manager = Unmanaged<CarbonHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    // Carbon dispatches events for the application event target from the main run loop, so this
    // callback always runs on the main thread. `assumeIsolated` states that and traps instead of
    // racing if it were ever called from another thread.
    return MainActor.assumeIsolated {
        manager.handlePress(of: hotkeyID)
    }
}
