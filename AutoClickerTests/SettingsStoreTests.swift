import Carbon
import CoreGraphics
import Foundation
import Testing

@testable import AutoClicker

/// Every test gets its own `UserDefaults` suite, removed again in `deinit`, so tests never touch
/// `UserDefaults.standard` and can run in parallel.
@MainActor
final class SettingsStoreTests {
    private let suiteName = TestDefaultsSuite.makeName(prefix: "SettingsStoreTests")
    private let defaults: UserDefaults
    private let key = "clickConfiguration"

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        // `deinit` is nonisolated and cannot touch the non-Sendable `defaults`, so a fresh handle on the same suite
        // removes it.
        TestDefaultsSuite.remove(suiteName)
    }

    private static let customConfiguration = ClickConfiguration(
        clickType: .double,
        interval: ClickInterval(hours: 1, minutes: 2, seconds: 3, milliseconds: 456, jitterMilliseconds: 25),
        target: .fixed(CGPoint(x: 1234.5, y: -180)),
        stopCondition: .afterDuration(.seconds(2) + .milliseconds(500)),
        modifiers: [.shift, .command])

    /// `customConfiguration` as versions 1 and 2 could hold it: they predate modifiers.
    private static let legacyConfiguration: ClickConfiguration = {
        var configuration = customConfiguration
        configuration.modifiers = []
        return configuration
    }()

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

    @Test(arguments: [
        ClickModifiers(),
        .shift, .control, .option, .command,
        [.shift, .command], [.control, .option], [.shift, .control, .option, .command],
    ])
    func roundTripsEveryKindOfModifierSet(modifiers: ClickModifiers) {
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.default
        settings.configuration.modifiers = modifiers
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

    @Test func versionOneMigratesWithF6AsTheShortcutAndNoModifiers() {
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
        #expect(loaded.configuration.modifiers.isEmpty)
        #expect(loaded.toggleHotkey == .f6)
        #expect(loaded.toggleHotkey.keyLabel == nil)
    }

    @Test func versionOneWrittenByTheEncoderMigratesToo() throws {
        store(json: #"{"version":1,"configuration":"# + (try Self.json(of: Self.legacyConfiguration)) + "}")
        #expect(SettingsStore(defaults: defaults).load() == AppSettings(configuration: Self.legacyConfiguration))
    }

    @Test func versionTwoMigratesWithItsShortcutAndNoModifiers() {
        // A literal blob in the version 2 format, so the test does not depend on today's encoder.
        store(
            json: #"{"version":2,"configuration":{"clickType":"middle","#
                + #""interval":{"hours":0,"minutes":1,"seconds":0,"milliseconds":5,"jitterMilliseconds":0},"#
                + #""target":{"kind":"currentCursor"},"#
                + #""stopCondition":{"kind":"never"}},"#
                + #""toggleHotkey":{"keyCode":40,"modifiers":6144,"keyLabel":"K"}}"#)

        let loaded = SettingsStore(defaults: defaults).load()

        let expected = ClickConfiguration(
            clickType: .middle,
            interval: ClickInterval(minutes: 1, milliseconds: 5),
            target: .currentCursor,
            stopCondition: .never)
        #expect(loaded.configuration == expected)
        #expect(loaded.configuration.modifiers.isEmpty)
        #expect(loaded.toggleHotkey == Self.customHotkey)
        #expect(loaded.toggleHotkey.keyLabel == "K")
    }

    @Test func versionTwoWrittenByTheEncoderMigratesToo() throws {
        let configuration = try Self.json(of: Self.legacyConfiguration)
        store(
            json: #"{"version":2,"configuration":"# + configuration
                + #","toggleHotkey":{"keyCode":40,"modifiers":6144}}"#)
        #expect(
            SettingsStore(defaults: defaults).load()
                == AppSettings(configuration: Self.legacyConfiguration, toggleHotkey: Self.customHotkey))
    }

    @Test func versionTwoWithAnInvalidShortcutFallsBackToF6AndKeepsTheConfiguration() throws {
        let configuration = try Self.json(of: Self.legacyConfiguration)
        store(
            json: #"{"version":2,"configuration":"# + configuration
                + #","toggleHotkey":{"keyCode":53,"modifiers":0}}"#)
        #expect(SettingsStore(defaults: defaults).load() == AppSettings(configuration: Self.legacyConfiguration))
    }

    @Test(arguments: [1, 2])
    func migratedSettingsAreSavedAsVersionThree(version: Int) throws {
        let configuration = try Self.json(of: Self.legacyConfiguration)
        let hotkey = version == 2 ? #","toggleHotkey":{"keyCode":97,"modifiers":0}"# : ""
        store(json: #"{"version":\#(version),"configuration":"# + configuration + hotkey + "}")
        let store = SettingsStore(defaults: defaults)

        store.save(store.load())

        let envelope = try storedEnvelope()
        #expect(envelope["version"] as? Int == 3)
        #expect(envelope["toggleHotkey"] is [String: Any])
        let storedConfiguration = try #require(envelope["configuration"] as? [String: Any])
        #expect(storedConfiguration["modifiers"] as? [String] == [])
        #expect(store.load() == AppSettings(configuration: Self.legacyConfiguration, toggleHotkey: .f6))
    }

    @Test func versionThreeLiteralLoadsItsModifiers() {
        store(
            json: #"{"version":3,"configuration":{"clickType":"left","#
                + #""interval":{"hours":0,"minutes":0,"seconds":0,"milliseconds":100,"jitterMilliseconds":0},"#
                + #""target":{"kind":"currentCursor"},"stopCondition":{"kind":"never"},"#
                + #""modifiers":["shift","command"]},"#
                + #""toggleHotkey":{"keyCode":97,"modifiers":0}}"#)
        var expected = AppSettings.default
        expected.configuration.modifiers = [.shift, .command]
        #expect(SettingsStore(defaults: defaults).load() == expected)
    }

    @Test func versionThreeWithoutModifiersLoadsTheDefault() {
        // Version 3 always stores the modifiers; a configuration without them is not version 3 and is not guessed at.
        store(
            json: #"{"version":3,"configuration":{"clickType":"right","#
                + #""interval":{"hours":0,"minutes":0,"seconds":1,"milliseconds":0,"jitterMilliseconds":0},"#
                + #""target":{"kind":"currentCursor"},"stopCondition":{"kind":"never"}},"#
                + #""toggleHotkey":{"keyCode":97,"modifiers":0}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
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

    @Test(arguments: [2, 3])
    func malformedConfigurationLoadsTheDefault(version: Int) {
        store(
            json: #"{"version":\#(version),"configuration":{"clickType":"triple"},"#
                + #""toggleHotkey":{"keyCode":40,"modifiers":6144}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [2, 3])
    func envelopeWithoutAHotkeyLoadsTheDefault(version: Int) throws {
        // Versions 2 and 3 always have a shortcut; an envelope without one must not be guessed at.
        let configuration = try Self.json(of: Self.customConfiguration)
        store(json: #"{"version":\#(version),"configuration":"# + configuration + "}")
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func malformedHotkeyLoadsTheDefault() throws {
        let configuration = try Self.json(of: Self.customConfiguration)
        store(json: #"{"version":3,"configuration":"# + configuration + #","toggleHotkey":{"keyCode":"F6"}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func malformedModifiersLoadTheDefault() {
        store(
            json: #"{"version":3,"configuration":{"clickType":"left","#
                + #""interval":{"hours":0,"minutes":0,"seconds":0,"milliseconds":100,"jitterMilliseconds":0},"#
                + #""target":{"kind":"currentCursor"},"stopCondition":{"kind":"never"},"#
                + #""modifiers":"shift"},"#
                + #""toggleHotkey":{"keyCode":97,"modifiers":0}}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [
        #"{"keyCode":53,"modifiers":0}"#,  // Esc, reserved for the emergency stop
        #"{"keyCode":40,"modifiers":0}"#,  // K without a modifier
        #"{"keyCode":40,"modifiers":512}"#,  // ⇧K
        #"{"keyCode":56,"modifiers":256}"#,  // Shift key on its own
        #"{"keyCode":97,"modifiers":1024}"#,  // F6 with Caps Lock, not a shortcut modifier
    ])
    func invalidStoredShortcutFallsBackToF6AndKeepsTheConfiguration(hotkeyJSON: String) throws {
        let configuration = try Self.json(of: Self.customConfiguration)
        store(json: #"{"version":3,"configuration":"# + configuration + #","toggleHotkey":"# + hotkeyJSON + "}")
        #expect(SettingsStore(defaults: defaults).load() == AppSettings(configuration: Self.customConfiguration))
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

    @Test func savesAVersionThreeJSONEnvelope() throws {
        SettingsStore(defaults: defaults).save(Self.customSettings)
        let envelope = try storedEnvelope()
        #expect(envelope["version"] as? Int == 3)
        #expect(SettingsStore.currentVersion == 3)
        #expect(Set(envelope.keys) == ["version", "configuration", "toggleHotkey"])
        let configuration = try #require(envelope["configuration"] as? [String: Any])
        #expect(configuration["clickType"] as? String == "double")
        // Menu order (⌃⌥⇧⌘), whatever order the set was built in.
        #expect(configuration["modifiers"] as? [String] == ["shift", "command"])
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
