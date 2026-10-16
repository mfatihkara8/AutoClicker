import AppKit
import Carbon
import Testing

@testable import AutoClicker

/// Drives `LocalShortcutRecorder` through injected monitor functions, so no real `NSEvent` monitor is installed.
/// The events are created with `NSEvent.keyEvent(...)` and handed to the handler directly; nothing is posted.
@MainActor
struct LocalShortcutRecorderTests {
    /// Stands in for `NSEvent`'s monitor API and records how the recorder uses it.
    @MainActor
    final class FakeMonitors {
        private(set) var installedMasks: [NSEvent.EventTypeMask] = []
        private(set) var removedTokens: [Int] = []
        private var handlers: [Int: LocalShortcutRecorder.EventHandler] = [:]
        private var nextToken = 0

        var activeCount: Int {
            handlers.count
        }

        func install(_ mask: NSEvent.EventTypeMask, _ handler: @escaping LocalShortcutRecorder.EventHandler) -> Any? {
            installedMasks.append(mask)
            nextToken += 1
            handlers[nextToken] = handler
            return nextToken
        }

        func remove(_ token: Any) {
            guard let token = token as? Int else {
                Issue.record("Unexpected monitor token \(token)")
                return
            }
            removedTokens.append(token)
            handlers[token] = nil
        }

        /// Delivers `event` to the most recently installed monitor that is still active, as AppKit would.
        func deliver(_ event: NSEvent) -> NSEvent? {
            guard let token = handlers.keys.max(), let handler = handlers[token] else { return event }
            return handler(event)
        }

        /// Calls the handler of `token` even after removal, to check that a stale call is harmless.
        func handler(for token: Int) -> LocalShortcutRecorder.EventHandler? {
            handlers[token]
        }
    }

    private let monitors = FakeMonitors()

    private func makeRecorder() -> LocalShortcutRecorder {
        let monitors = monitors
        return LocalShortcutRecorder(
            installMonitor: { monitors.install($0, $1) },
            removeMonitor: { monitors.remove($0) })
    }

    private static func keyEvent(
        _ type: NSEvent.EventType = .keyDown,
        keyCode: Int = kVK_ANSI_K,
        flags: NSEvent.ModifierFlags = [.control, .option],
        characters: String = "k"
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                characters: characters, charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode)))
    }

    // MARK: - Monitor lifetime

    @Test func newRecorderInstallsNothing() {
        let recorder = makeRecorder()
        #expect(recorder.isRecording == false)
        #expect(monitors.installedMasks.isEmpty)
    }

    @Test func beginInstallsOneKeyDownMonitor() {
        let recorder = makeRecorder()
        recorder.begin { _ in }
        #expect(recorder.isRecording)
        #expect(monitors.installedMasks == [.keyDown])
        #expect(monitors.activeCount == 1)
    }

    @Test func capturedKeyEndsRecordingAndIsSwallowed() throws {
        let recorder = makeRecorder()
        var captured: [RecordedKey] = []
        recorder.begin { captured.append($0) }

        let passedOn = monitors.deliver(try Self.keyEvent())

        #expect(passedOn == nil)
        #expect(captured.count == 1)
        #expect(captured.first?.keyCode == UInt32(kVK_ANSI_K))
        #expect(captured.first?.modifiers == UInt32(controlKey | optionKey))
        #expect(captured.first?.characters != nil)
        #expect(recorder.isRecording == false)
        #expect(monitors.removedTokens == [1])
        #expect(monitors.activeCount == 0)
    }

    @Test func aStaleCallAfterCaptureIsPassedOn() throws {
        let recorder = makeRecorder()
        var captureCount = 0
        recorder.begin { _ in captureCount += 1 }
        let staleHandler = try #require(monitors.handler(for: 1))
        _ = monitors.deliver(try Self.keyEvent())

        let event = try Self.keyEvent(keyCode: kVK_ANSI_J)
        #expect(staleHandler(event) === event)
        #expect(captureCount == 1)
    }

    @Test func cancelRemovesTheMonitorWithoutCallingTheHandler() throws {
        let recorder = makeRecorder()
        var captureCount = 0
        recorder.begin { _ in captureCount += 1 }

        recorder.cancel()

        #expect(recorder.isRecording == false)
        #expect(monitors.removedTokens == [1])
        #expect(monitors.activeCount == 0)
        #expect(captureCount == 0)
    }

    @Test func cancelWithoutBeginDoesNothing() {
        let recorder = makeRecorder()
        recorder.cancel()
        #expect(monitors.removedTokens.isEmpty)
    }

    @Test func beginWhileRecordingKeepsOneMonitorAndReplacesTheHandler() throws {
        let recorder = makeRecorder()
        var calls: [String] = []
        recorder.begin { _ in calls.append("first") }
        recorder.begin { _ in calls.append("second") }

        #expect(monitors.installedMasks.count == 1)
        _ = monitors.deliver(try Self.keyEvent())
        #expect(calls == ["second"])
    }

    @Test func handlerMayBeginANewSession() throws {
        let recorder = makeRecorder()
        var captureCount = 0
        recorder.begin { [weak recorder] _ in
            captureCount += 1
            recorder?.begin { _ in captureCount += 1 }
        }

        _ = monitors.deliver(try Self.keyEvent())
        #expect(recorder.isRecording)
        #expect(monitors.activeCount == 1)

        _ = monitors.deliver(try Self.keyEvent())
        #expect(captureCount == 2)
        #expect(monitors.activeCount == 0)
    }

    @Test func releasingTheRecorderRemovesItsMonitor() {
        var recorder: LocalShortcutRecorder? = makeRecorder()
        recorder?.begin { _ in }
        #expect(monitors.activeCount == 1)

        recorder = nil

        #expect(monitors.activeCount == 0)
        #expect(monitors.removedTokens == [1])
    }

    @Test func nonKeyDownEventsArePassedOn() throws {
        let recorder = makeRecorder()
        var captureCount = 0
        recorder.begin { _ in captureCount += 1 }

        let keyUp = try Self.keyEvent(.keyUp)
        #expect(monitors.deliver(keyUp) === keyUp)
        #expect(captureCount == 0)
        #expect(recorder.isRecording)
        recorder.cancel()
    }

    // MARK: - Event conversion

    @Test func recordedKeyCarriesTheKeyCodeAndCarbonModifiers() throws {
        let event = try Self.keyEvent(keyCode: kVK_F6, flags: [.command, .shift, .function], characters: "\u{F709}")
        let key = LocalShortcutRecorder.recordedKey(from: event)
        #expect(key.keyCode == UInt32(kVK_F6))
        #expect(key.modifiers == UInt32(cmdKey | shiftKey))
    }
}
