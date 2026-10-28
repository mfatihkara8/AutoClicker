import Carbon
import Foundation
import Testing

@testable import AutoClicker

/// The configurable start/stop shortcut (T-703): recording, validation, registration, persistence and the hints.
@MainActor
struct MainViewModelShortcutTests {
    private typealias Harness = MainViewModelHarness

    /// ⌃⌥K as the recorder reports it on a US layout.
    private static let controlOptionK = RecordedKey(
        keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), characters: "k")
    /// The hotkey `controlOptionK` becomes.
    private static let customHotkey = Hotkey(
        keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), keyLabel: "K")

    private static let registrationError = HotkeyRegistrationError.registrationFailed(customHotkey, status: -9878)

    /// A harness whose store already holds `customHotkey` as the shortcut.
    private static func harnessWithCustomShortcut() throws -> Harness {
        let harness = try Harness()
        harness.store.save(AppSettings(configuration: .default, toggleHotkey: customHotkey))
        return harness
    }

    // MARK: - Activation

    @Test func activateRegistersThePersistedShortcut() throws {
        let harness = try Self.harnessWithCustomShortcut()
        let viewModel = harness.viewModel

        viewModel.activate()

        #expect(viewModel.toggleHotkey == Self.customHotkey)
        #expect(viewModel.toggleHotkey.keyLabel == "K")
        #expect(harness.hotkeys.registerCalls == [Self.customHotkey])
        #expect(harness.hotkeys.isRegistered(.f6) == false)
        #expect(viewModel.hotkeyWarning == nil)
        #expect(viewModel.isDefaultShortcut == false)
    }

    @Test func thePersistedShortcutTogglesTheRun() async throws {
        let harness = try Self.harnessWithCustomShortcut()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.activate()

        #expect(harness.hotkeys.simulatePress(Self.customHotkey))
        #expect(viewModel.isRunning)
        #expect(harness.hotkeys.simulatePress(Self.customHotkey))
        #expect(await harness.waitForStop())
        #expect(viewModel.lastStopReason == .hotkey)
    }

    @Test func activationFailureNamesTheCurrentShortcut() throws {
        let harness = try Self.harnessWithCustomShortcut()
        harness.hotkeys.registrationErrors[Self.customHotkey] = Self.registrationError
        let viewModel = harness.viewModel

        viewModel.activate()

        let warning = try #require(viewModel.hotkeyWarning)
        #expect(warning.contains("⌃⌥K"))
        #expect(viewModel.advertisedToggleHotkeyName == nil)
    }

    // MARK: - Recording

    @Test func recordingUnregistersTheShortcutAndCancelRestoresIt() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()

        viewModel.beginRecordingShortcut()

        #expect(viewModel.isRecordingShortcut)
        #expect(harness.recorder.isRecording)
        #expect(harness.hotkeys.isRegistered(.f6) == false)
        #expect(harness.hotkeys.unregisterCalls == [.f6])

        viewModel.cancelRecordingShortcut()

        #expect(viewModel.isRecordingShortcut == false)
        #expect(harness.recorder.isRecording == false)
        #expect(harness.recorder.cancelCallCount == 1)
        #expect(harness.hotkeys.isRegistered(.f6))
        #expect(viewModel.toggleHotkey == .f6)
        #expect(harness.defaults.setCallCount == 0)
    }

    @Test func beginRecordingTwiceStartsOneSession() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()

        viewModel.beginRecordingShortcut()
        viewModel.beginRecordingShortcut()

        #expect(harness.recorder.beginCallCount == 1)
        #expect(harness.hotkeys.unregisterCalls == [.f6])
    }

    @Test func cancelWithoutRecordingDoesNothing() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()

        viewModel.cancelRecordingShortcut()

        #expect(harness.recorder.cancelCallCount == 0)
        #expect(harness.hotkeys.registerCalls == [.f6])
    }

    @Test func acceptedShortcutIsRegisteredAndPersisted() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        #expect(harness.recorder.simulate(Self.controlOptionK))

        #expect(viewModel.isRecordingShortcut == false)
        #expect(viewModel.toggleHotkey == Self.customHotkey)
        #expect(viewModel.toggleHotkey.displayName == "⌃⌥K")
        #expect(viewModel.shortcutWarning == nil)
        #expect(viewModel.hotkeyWarning == nil)
        #expect(harness.hotkeys.registeredHotkeys == [Self.customHotkey])

        let saved = harness.store.load()
        #expect(saved.toggleHotkey == Self.customHotkey)
        #expect(saved.toggleHotkey.keyLabel == "K")
        // The immediate save also wrote the configuration edit that was still waiting for its debounce.
        #expect(saved.configuration == Harness.configuration())

        // The new shortcut works and the old one is gone.
        #expect(harness.hotkeys.simulatePress(.f6) == false)
        #expect(harness.hotkeys.simulatePress(Self.customHotkey))
        #expect(viewModel.isRunning)
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    @Test func recordingTheCurrentShortcutAgainKeepsItRegistered() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        harness.recorder.simulate(RecordedKey(keyCode: UInt32(kVK_F6), characters: "\u{F709}"))

        #expect(viewModel.toggleHotkey == .f6)
        #expect(harness.hotkeys.isRegistered(.f6))
        #expect(viewModel.shortcutWarning == nil)
    }

    @Test func shiftOnlyIsRejectedWithAHint() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        harness.recorder.simulate(
            RecordedKey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(shiftKey), characters: "k"))

        #expect(viewModel.shortcutWarning == ShortcutValidator.Rejection.shiftOnly.displayText)
        #expect(viewModel.isRecordingShortcut == false)
        #expect(viewModel.toggleHotkey == .f6)
        #expect(harness.hotkeys.registeredHotkeys == [.f6])
        #expect(harness.defaults.setCallCount == 0)
    }

    @Test func keyWithoutAModifierIsRejectedWithAHint() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        harness.recorder.simulate(RecordedKey(keyCode: UInt32(kVK_Space), characters: " "))

        #expect(viewModel.shortcutWarning == ShortcutValidator.Rejection.missingModifier.displayText)
        #expect(harness.hotkeys.registeredHotkeys == [.f6])
    }

    @Test(arguments: [0, cmdKey, shiftKey])
    func escapeCancelsRecordingWithoutAWarning(modifiers: Int) throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        harness.recorder.simulate(RecordedKey(keyCode: UInt32(kVK_Escape), modifiers: UInt32(modifiers)))

        #expect(viewModel.isRecordingShortcut == false)
        #expect(viewModel.shortcutWarning == nil)
        #expect(viewModel.toggleHotkey == .f6)
        #expect(harness.hotkeys.registeredHotkeys == [.f6])
        #expect(harness.defaults.setCallCount == 0)
    }

    @Test func beginningAgainClearsTheLastWarning() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()
        harness.recorder.simulate(RecordedKey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(shiftKey)))
        #expect(viewModel.shortcutWarning != nil)

        viewModel.beginRecordingShortcut()

        #expect(viewModel.shortcutWarning == nil)
        #expect(viewModel.isRecordingShortcut)
    }

    @Test func registrationFailureKeepsTheOldShortcutAndWarns() throws {
        let harness = try Harness()
        harness.hotkeys.registrationErrors[Self.customHotkey] = Self.registrationError
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        harness.recorder.simulate(Self.controlOptionK)

        let warning = try #require(viewModel.shortcutWarning)
        #expect(warning.contains("in use"))
        #expect(warning.contains("F6"))
        #expect(viewModel.hotkeyWarning == nil)
        #expect(viewModel.toggleHotkey == .f6)
        #expect(harness.hotkeys.registerCalls == [.f6, Self.customHotkey, .f6])
        #expect(harness.hotkeys.registeredHotkeys == [.f6])
        #expect(harness.defaults.setCallCount == 0)
        #expect(harness.store.load().toggleHotkey == .f6)
    }

    @Test func recorderThatCannotStartRestoresTheShortcut() throws {
        let harness = try Harness()
        harness.recorder.failsToBegin = true
        let viewModel = harness.viewModel
        viewModel.activate()

        viewModel.beginRecordingShortcut()

        #expect(viewModel.isRecordingShortcut == false)
        #expect(viewModel.shortcutWarning != nil)
        #expect(harness.hotkeys.registeredHotkeys == [.f6])
    }

    @Test func changingTheShortcutClearsAFailedActivationWarning() throws {
        let harness = try Harness()
        harness.hotkeys.registrationErrors[.f6] = .registrationFailed(.f6, status: -9878)
        let viewModel = harness.viewModel
        viewModel.activate()
        #expect(viewModel.hotkeyWarning != nil)

        viewModel.beginRecordingShortcut()
        harness.recorder.simulate(Self.controlOptionK)

        #expect(viewModel.hotkeyWarning == nil)
        #expect(viewModel.shortcutWarning == nil)
        #expect(harness.hotkeys.registeredHotkeys == [Self.customHotkey])
    }

    @Test func recordingBeforeActivationSavesAndActivationRegistersTheNewShortcut() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        viewModel.beginRecordingShortcut()
        harness.recorder.simulate(Self.controlOptionK)

        #expect(viewModel.toggleHotkey == Self.customHotkey)
        #expect(harness.hotkeys.registerCalls.isEmpty)
        #expect(harness.store.load().toggleHotkey == Self.customHotkey)

        viewModel.activate()
        #expect(harness.hotkeys.registerCalls == [Self.customHotkey])
    }

    // MARK: - Locked while running

    @Test func recordingIsBlockedWhileRunning() async throws {
        let harness = try Self.harnessWithCustomShortcut()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.activate()
        viewModel.start()
        #expect(viewModel.canChangeShortcut == false)

        viewModel.beginRecordingShortcut()
        viewModel.resetShortcut()

        #expect(viewModel.isRecordingShortcut == false)
        #expect(harness.recorder.beginCallCount == 0)
        #expect(viewModel.toggleHotkey == Self.customHotkey)
        #expect(harness.hotkeys.isRegistered(Self.customHotkey))

        viewModel.stop()
        #expect(await harness.waitForStop())
        #expect(viewModel.canChangeShortcut)
    }

    @Test func startingARunCancelsRecordingAndRestoresTheShortcut() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        // The menu bar can start a run while the main window is recording.
        viewModel.start()

        #expect(viewModel.isRunning)
        #expect(viewModel.isRecordingShortcut == false)
        #expect(harness.recorder.isRecording == false)
        #expect(harness.hotkeys.isRegistered(.f6))
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    // MARK: - Reset

    @Test func resetGoesBackToF6() throws {
        let harness = try Self.harnessWithCustomShortcut()
        let viewModel = harness.viewModel
        viewModel.activate()

        viewModel.resetShortcut()

        #expect(viewModel.toggleHotkey == .f6)
        #expect(viewModel.isDefaultShortcut)
        #expect(harness.hotkeys.registeredHotkeys == [.f6])
        #expect(harness.hotkeys.unregisterCalls == [Self.customHotkey])
        #expect(harness.store.load().toggleHotkey == .f6)
    }

    @Test func resetCancelsARecordingInProgress() throws {
        let harness = try Self.harnessWithCustomShortcut()
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()

        viewModel.resetShortcut()

        #expect(viewModel.isRecordingShortcut == false)
        #expect(harness.recorder.isRecording == false)
        #expect(viewModel.toggleHotkey == .f6)
        #expect(harness.hotkeys.registeredHotkeys == [.f6])
    }

    @Test func resetThatCannotRegisterF6KeepsTheCurrentShortcut() throws {
        let harness = try Self.harnessWithCustomShortcut()
        harness.hotkeys.registrationErrors[.f6] = .registrationFailed(.f6, status: -9878)
        let viewModel = harness.viewModel
        viewModel.activate()

        viewModel.resetShortcut()

        #expect(viewModel.toggleHotkey == Self.customHotkey)
        #expect(viewModel.shortcutWarning != nil)
        #expect(harness.hotkeys.registeredHotkeys == [Self.customHotkey])
        #expect(harness.store.load().toggleHotkey == Self.customHotkey)
    }

    // MARK: - Hints

    @Test func menuBarShowsTheCustomShortcut() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.activate()
        viewModel.beginRecordingShortcut()
        harness.recorder.simulate(Self.controlOptionK)

        let presentation = MenuBarPresentation(
            isRunning: viewModel.isRunning,
            totalClicks: viewModel.totalClicks,
            lastStopReason: viewModel.lastStopReason,
            toggleHotkeyName: viewModel.advertisedToggleHotkeyName,
            clickType: viewModel.configuration.clickType,
            modifiers: viewModel.configuration.modifiers,
            locale: Locale(identifier: "en_US"))

        #expect(viewModel.advertisedToggleHotkeyName == "⌃⌥K")
        #expect(presentation.startStopTitle == "Start Clicking (⌃⌥K)")
    }

    @Test func emergencyStopWarningNamesTheCurrentShortcut() async throws {
        let harness = try Self.harnessWithCustomShortcut()
        harness.hotkeys.registrationErrors[.escape] = .registrationFailed(.escape, status: -9878)
        let viewModel = harness.viewModel
        viewModel.configuration = Harness.configuration()

        viewModel.start()

        let warning = try #require(viewModel.emergencyStopWarning)
        #expect(warning.contains("⌃⌥K"))
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    // MARK: - Lifetime

    @Test func releasingTheViewModelCancelsRecordingAndUnregistersTheCustomShortcut() throws {
        let harness = try Self.harnessWithCustomShortcut()
        var viewModel: MainViewModel? = harness.makeViewModel()
        viewModel?.activate()
        #expect(harness.hotkeys.isRegistered(Self.customHotkey))

        viewModel = nil

        #expect(harness.hotkeys.registeredHotkeys.isEmpty)
        #expect(harness.recorder.cancelCallCount == 1)
    }
}
