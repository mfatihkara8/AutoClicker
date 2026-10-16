/// Captures the next key press in the app's own windows so the user can choose a new start/stop shortcut (ADR-008).
///
/// The production implementation is `LocalShortcutRecorder`; tests use `MockShortcutRecorder`. Recording is one-shot:
/// the first captured key ends it, so nothing watches the keyboard outside an explicit recording session.
@MainActor
protocol ShortcutRecording: AnyObject {
    /// Whether a recording session is active, that is, between `begin(_:)` and the captured key or `cancel()`.
    var isRecording: Bool { get }

    /// Starts recording and calls `handler` once, on the main actor, with the next key press.
    ///
    /// Recording has already ended when `handler` runs, so the handler may call `begin(_:)` again. Calling `begin(_:)`
    /// while recording replaces the pending handler. The recorder keeps `handler` until a key is captured or recording
    /// is cancelled, so capture `[weak self]` in it.
    func begin(_ handler: @escaping @MainActor (RecordedKey) -> Void)

    /// Ends recording without calling the handler. Does nothing when not recording.
    func cancel()
}
