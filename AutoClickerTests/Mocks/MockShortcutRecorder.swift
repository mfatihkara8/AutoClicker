@testable import AutoClicker

/// A `ShortcutRecording` implementation that installs no event monitor.
///
/// `simulate(_:)` stands in for the user pressing a key while recording. Like the real recorder, the session ends
/// before the handler runs.
@MainActor
final class MockShortcutRecorder: ShortcutRecording {
    private var handler: (@MainActor (RecordedKey) -> Void)?

    private(set) var beginCallCount = 0
    private(set) var cancelCallCount = 0

    /// When `true`, `begin(_:)` fails the way a recorder whose monitor could not be installed does: it stays idle.
    var failsToBegin = false

    var isRecording: Bool {
        handler != nil
    }

    func begin(_ handler: @escaping @MainActor (RecordedKey) -> Void) {
        beginCallCount += 1
        guard !failsToBegin else { return }
        self.handler = handler
    }

    func cancel() {
        cancelCallCount += 1
        handler = nil
    }

    /// Delivers `key` as if the user pressed it while recording.
    ///
    /// - Returns: `false` when not recording, mirroring the real recorder, which has no monitor then.
    @discardableResult
    func simulate(_ key: RecordedKey) -> Bool {
        guard let handler else { return false }
        self.handler = nil
        handler(key)
        return true
    }
}
