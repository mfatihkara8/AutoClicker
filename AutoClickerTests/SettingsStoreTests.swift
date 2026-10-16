import Carbon
import CoreGraphics
import Foundation
import Testing

@testable import AutoClicker

/// Every test gets its own `UserDefaults` suite, removed again in `deinit`, so tests never touch
/// `UserDefaults.standard` and can run in parallel.
@MainActor
final class SettingsStoreTests {
    private let suiteName = "AutoClickerTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let key = "clickConfiguration"

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        // `deinit` is nonisolated and cannot touch the non-Sendable `defaults`, so a fresh handle on the same suite
        // removes it.
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private static let customConfiguration = ClickConfiguration(
        clickType: .double,
        interval: ClickInterval(hours: 1, minutes: 2, seconds: 3, milliseconds: 456, jitterMilliseconds: 25),
        target: .fixed(CGPoint(x: 1234.5, y: -180)),
        stopCondition: .afterDuration(.seconds(2) + .milliseconds(500)))

    /// ⌃⌥K, recorded on a layout that labels the key "K".
    private static let customHotkey = Hotkey(
        keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), keyLabel: "K")

    private static let customSettings = AppSettings(configuration: customConfiguration, toggleHotkey: customHotkey)

    private func storedEnvelope() throws -> [String: Any] {
        let data = try #require(defaults.data(forKey: key))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func store(json: String) {
        defaults.set(Data(json.utf8), forKey: key)
    }

    private static func json(of configuration: ClickConfiguration) throws -> String {
        String(decoding: try JSONEncoder().encode(configuration), as: UTF8.self)
    }

    // MARK: - Round trip

    @Test func roundTripsNonDefaultSettings() {
        let store = SettingsStore(defaults: defaults)
        store.save(Self.customSettings)
        let loaded = store.load()
        #expect(loaded == Self.customSettings)
        // `Hotkey` equality ignores the label, so check it separately.
        #expect(loaded.toggleHotkey.keyLabel == "K")
    }

    @Test(arguments: [
        Hotkey.f6,
        Hotkey(keyCode: UInt32(kVK_F13)),
        Hotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey)),
        Hotkey(keyCode: UInt32(kVK_ANSI_Semicolon), modifiers: UInt32(cmdKey), keyLabel: "Ş"),
    ])
    func roundTripsEveryKindOfHotkey(hotkey: Hotkey) {
        let store = SettingsStore(defaults: defaults)
        store.save(AppSettings(configuration: .default, toggleHotkey: hotkey))
        let loaded = store.load().toggleHotkey
        #expect(loaded == hotkey)
        #expect(loaded.keyLabel == hotkey.keyLabel)
    }

    @Test(arguments: ClickType.allCases)
    func roundTripsEveryClickType(clickType: ClickType) {
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.default
        settings.configuration.clickType = clickType
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test(arguments: [
        StopCondition.never,
        .afterClicks(1_000),
        .afterDuration(.seconds(90)),
        .afterDuration(.milliseconds(1_500)),
    ])
    func roundTripsEveryStopCondition(stopCondition: StopCondition) {
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.default
        settings.configuration.stopCondition = stopCondition
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test(arguments: [ClickTarget.currentCursor, .fixed(CGPoint(x: 0, y: 0)), .fixed(CGPoint(x: -2560, y: 42.25))])
    func roundTripsEveryTarget(target: ClickTarget) {
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.default
        settings.configuration.target = target
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test func laterSaveReplacesTheEarlierOne() {
        let store = SettingsStore(defaults: defaults)
        store.save(Self.customSettings)
        store.save(.default)
        #expect(store.load() == .default)
    }

    // MARK: - Migration

    @Test func versionOneMigratesWithF6AsTheShortcut() {
        // A literal blob in the version 1 format, so the test does not depend on today's encoder.
        store(
            json: #"{"version":1,"configuration":{"clickType":"right","#
                + #""interval":{"hours":0,"minutes":0,"seconds":2,"milliseconds":250,"jitterMilliseconds":10},"#
                + #""target":{"kind":"fixed","x":640,"y":-12.5},"#
                + #""stopCondition":{"kind":"afterClicks","clicks":42}}}"#)

        let loaded = SettingsStore(defaults: defaults).load()

        let expected = ClickConfiguration(
            clickType: .right,
            interval: ClickInterval(seconds: 2, milliseconds: 250, jitterMilliseconds: 10),
            target: .fixed(CGPoint(x: 640, y: -12.5)),
            stopCondition: .afterClicks(42))
        #expect(loaded.configuration == expected)
        #expect(loaded.toggleHotkey == .f6)
        #expect(loaded.toggleHotkey.keyLabel == nil)
    }

    @Test func versionOneWrittenByTheEncoderMigratesToo() throws {
        store(json: #"{"version":1,"configuration":"# + (try Self.json(of: Self.customConfiguration)) + "}")
        #expect(SettingsStore(defaults: defaults).load() == AppSettings(configuration: Self.customConfiguration))
    }

    @Test func migratedSettingsAreSavedAsVersionTwo() throws {
        store(json: #"{"version":1,"configuration":"# + (try Self.json(of: Self.customConfiguration)) + "}")
        let store = SettingsStore(defaults: defaults)

        store.save(store.load())

        let envelope = try storedEnvelope()
        #expect(envelope["version"] as? Int == 2)
        #expect(envelope["toggleHotkey"] is [String: Any])
        #expect(store.load() == AppSettings(configuration: Self.customConfiguration, toggleHotkey: .f6))
    }

    @Test func malformedVersionOneLoadsTheDefault() {
        store(json: #"{"version":1,"configuration":{"clickType":"triple"}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    // MARK: - Fallbacks

    @Test func missingValueLoadsTheDefault() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.load() == .default)
    }

    @Test func corruptDataLoadsTheDefault() {
        store(json: "not json {")
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func wrongValueTypeLoadsTheDefault() {
        defaults.set("a string, not data", forKey: key)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func envelopeWithoutVersionLoadsTheDefault() throws {
        store(json: #"{"configuration":"# + (try Self.json(of: Self.customConfiguration)) + "}")
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func malformedConfigurationLoadsTheDefault() {
        store(
            json: #"{"version":2,"configuration":{"clickType":"triple"},"#
                + #""toggleHotkey":{"keyCode":40,"modifiers":6144}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func versionTwoWithoutAHotkeyLoadsTheDefault() throws {
        // Version 2 always has a shortcut; an envelope without one is not version 2 and must not be guessed at.
        store(json: #"{"version":2,"configuration":"# + (try Self.json(of: Self.customConfiguration)) + "}")
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func malformedHotkeyLoadsTheDefault() throws {
        let configuration = try Self.json(of: Self.customConfiguration)
        store(json: #"{"version":2,"configuration":"# + configuration + #","toggleHotkey":{"keyCode":"F6"}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [0, SettingsStore.currentVersion + 1, 99])
    func unknownVersionLoadsTheDefault(version: Int) throws {
        // A valid body under a version this build does not understand must not be guessed at.
        let configuration = try Self.json(of: Self.customConfiguration)
        store(
            json: #"{"version":\#(version),"configuration":"# + configuration
                + #","toggleHotkey":{"keyCode":40,"modifiers":6144}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    // MARK: - Format

    @Test func savesAVersionTwoJSONEnvelope() throws {
        SettingsStore(defaults: defaults).save(Self.customSettings)
        let envelope = try storedEnvelope()
        #expect(envelope["version"] as? Int == 2)
        #expect(SettingsStore.currentVersion == 2)
        #expect(Set(envelope.keys) == ["version", "configuration", "toggleHotkey"])
        let configuration = try #require(envelope["configuration"] as? [String: Any])
        #expect(configuration["clickType"] as? String == "double")
        let hotkey = try #require(envelope["toggleHotkey"] as? [String: Any])
        #expect(hotkey["keyCode"] as? Int == kVK_ANSI_K)
        #expect(hotkey["modifiers"] as? Int == controlKey | optionKey)
        #expect(hotkey["keyLabel"] as? String == "K")
    }

    @Test func usesTheInjectedKey() {
        let store = SettingsStore(defaults: defaults, key: "otherKey")
        store.save(Self.customSettings)
        #expect(defaults.data(forKey: "otherKey") != nil)
        #expect(defaults.data(forKey: key) == nil)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    // MARK: - SC-8

    @Test func freshStoreOnTheSameSuiteLoadsWhatAnotherSaved() throws {
        SettingsStore(defaults: defaults).save(Self.customSettings)
        // A new `UserDefaults` instance on the same suite stands in for a relaunched app.
        let relaunchedDefaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(SettingsStore(defaults: relaunchedDefaults).load() == Self.customSettings)
    }
}
