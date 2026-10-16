import AppKit

/// Records the next key press in the app's own windows with an `NSEvent` *local* monitor (ADR-008).
///
/// A local monitor only sees events AppKit is about to dispatch to this app, so it needs no Input Monitoring
/// permission. It is installed by `begin(_:)` and removed as soon as a key is captured, on `cancel()` and in `deinit`,
/// so the keyboard is never watched outside an explicit recording session. Global monitors and event taps are
/// forbidden (ADR-002) and never used.
///
/// The captured key-down is swallowed: it neither types into a focused field nor triggers a menu shortcut such as ⌘Q.
@MainActor
final class LocalShortcutRecorder: ShortcutRecording {
    /// What AppKit calls for each matching event; returning `nil` swallows the event.
    typealias EventHandler = (NSEvent) -> NSEvent?
    /// Installs a monitor for the given event mask and returns its token.
    typealias MonitorInstaller = @MainActor (NSEvent.EventTypeMask, @escaping EventHandler) -> Any?
    /// Removes a monitor by the token its installer returned.
    typealias MonitorRemover = @MainActor (Any) -> Void

    private let installMonitor: MonitorInstaller
    private let removeMonitor: MonitorRemover
    private var monitor: Any?
    private var handler: (@MainActor (RecordedKey) -> Void)?

    var isRecording: Bool {
        monitor != nil
    }

    /// Creates a recorder. Creating one has no system side effects; only `begin(_:)` installs a monitor.
    ///
    /// - Parameters:
    ///   - installMonitor: Installs the local monitor. Injected so tests can drive the recorder without a real one.
    ///   - removeMonitor: Removes the monitor `installMonitor` returned.
    init(
        installMonitor: @escaping MonitorInstaller = { mask, handler in
            NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
        },
        removeMonitor: @escaping MonitorRemover = { NSEvent.removeMonitor($0) }
    ) {
        self.installMonitor = installMonitor
        self.removeMonitor = removeMonitor
    }

    // `isolated` so the monitor, which is only touched on the main actor, can be removed here.
    isolated deinit {
        stopMonitoring()
    }

    func begin(_ handler: @escaping @MainActor (RecordedKey) -> Void) {
        self.handler = handler
        guard monitor == nil else { return }
        monitor = installMonitor(.keyDown) { [weak self] event in
            // AppKit calls local monitors from `sendEvent(_:)` on the main thread. `assumeIsolated` states that and
            // traps instead of racing if it ever were not.
            let isCaptured = MainActor.assumeIsolated {
                self?.capture(event) ?? false
            }
            return isCaptured ? nil : event
        }
    }

    func cancel() {
        stopMonitoring()
    }

    /// Converts a key-down event into a `RecordedKey`.
    ///
    /// The characters are taken without any modifiers applied, so ⇧⌘2 is labeled "2" rather than "@" or "\"", as in
    /// the menus. `charactersIgnoringModifiers` is the fallback, because it still applies Shift.
    static func recordedKey(from event: NSEvent) -> RecordedKey {
        RecordedKey(
            keyCode: UInt32(event.keyCode),
            modifiers: ShortcutValidator.carbonModifiers(from: event.modifierFlags),
            characters: event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers)
    }

    /// Ends the session and hands the key to the handler. Returns whether the event was consumed.
    private func capture(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let handler else { return false }
        let key = Self.recordedKey(from: event)
        // Removed before the handler runs, so the handler may begin a new session.
        stopMonitoring()
        handler(key)
        return true
    }

    private func stopMonitoring() {
        handler = nil
        if let monitor {
            self.monitor = nil
            removeMonitor(monitor)
        }
    }
}
