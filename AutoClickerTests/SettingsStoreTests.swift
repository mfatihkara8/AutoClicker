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
        modifiers: [.shift, .command],
        positionOffset: 30)

    /// `customConfiguration` as versions 1 and 2 could hold it: they predate modifiers and the position offset.
    private static let legacyConfiguration: ClickConfiguration = {
        var configuration = customConfiguration
        configuration.modifiers = []
        configuration.positionOffset = 0
        return configuration
    }()

    private static let gameProfileID = UUID(uuidString: "6F1C1B5E-2D7A-4C3B-9E8F-0123456789AB")!
    private static let workProfileID = UUID(uuidString: "0A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D")!

    private static let sequenceConfiguration = ClickConfiguration(
        clickType: .right,
        interval: ClickInterval(milliseconds: 250, jitterMilliseconds: 20),
        target: .sequence([
            ClickPoint(point: CGPoint(x: 10, y: 20), delayMilliseconds: 100),
            ClickPoint(point: CGPoint(x: -300, y: 40.5), delayMilliseconds: 1_500),
        ]),
        stopCondition: .afterClicks(10),
        modifiers: [.option],
        positionOffset: 5)

    private static let customProfiles = [
        Profile(id: gameProfileID, name: "Game", configuration: sequenceConfiguration),
        Profile(id: workProfileID, name: "Work", configuration: .default),
    ]

    /// ⌃⌥K, recorded on a layout that labels the key "K".
    private static let customHotkey = Hotkey(
        keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), keyLabel: "K")

    private static let customSettings = AppSettings(
        configuration: customConfiguration, toggleHotkey: customHotkey, profiles: customProfiles,
        activeProfileID: gameProfileID)

    /// The default configuration as version 4 stores it, for literal blobs.
    private static let defaultConfigurationJSON =
        #"{"clickType":"left","#
        + #""interval":{"hours":0,"minutes":0,"seconds":0,"milliseconds":100,"jitterMilliseconds":0},"#
        + #""target":{"kind":"currentCursor"},"stopCondition":{"kind":"never"},"modifiers":[],"positionOffset":0}"#

    /// `defaultConfigurationJSON` with a right click, so loading it can be told apart from falling back to `.default`.
    private static let rightClickConfigurationJSON = defaultConfigurationJSON.replacingOccurrences(
        of: #""left""#, with: #""right""#)

    private func storedEnvelope() throws -> [String: Any] {
        let data = try #require(defaults.data(forKey: key))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func store(json: String) {
        defaults.set(Data(json.utf8), forKey: key)
    }

    private static func json(of value: some Encodable) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    /// A version 4 envelope assembled from JSON fragments; F6, no profiles and no active profile unless given.
    private static func versionFourJSON(
        configuration: String, hotkey: String = #"{"keyCode":97,"modifiers":0}"#, profiles: String = "[]",
        activeProfileID: String = "null"
    ) -> String {
        #"{"version":4,"configuration":"# + configuration + #","toggleHotkey":"# + hotkey + #","profiles":"#
            + profiles + #","activeProfileID":"# + activeProfileID + "}"
    }

    // MARK: - Round trip

    @Test func roundTripsNonDefaultSettings() {
        let store = SettingsStore(defaults: defaults)
        store.save(Self.customSettings)
        let loaded = store.load()
        #expect(loaded == Self.customSettings)
        #expect(loaded.activeProfile == Self.customProfiles[0])
        // `Hotkey` equality ignores the label, so check it separately.
        #expect(loaded.toggleHotkey.keyLabel == "K")
    }

    @Test func roundTripsProfilesWithoutAnActiveOne() {
        let store = SettingsStore(defaults: defaults)
        let settings = AppSettings(configuration: .default, profiles: Self.customProfiles)
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test(arguments: [0, 1, 200])
    func roundTripsThePositionOffset(offset: Int) {
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.default
        settings.configuration.positionOffset = offset
        store.save(settings)
        #expect(store.load() == settings)
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

    @Test(arguments: [
        ClickTarget.currentCursor,
        .fixed(CGPoint(x: 0, y: 0)),
        .fixed(CGPoint(x: -2560, y: 42.25)),
        .sequence([]),
        .sequence([ClickPoint(point: CGPoint(x: 5, y: -6), delayMilliseconds: 86_400_000)]),
    ])
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

    @Test(arguments: [1, 2, 3])
    func migratedSettingsAreSavedAsVersionFour(version: Int) throws {
        let configuration = try Self.json(of: Self.legacyConfiguration)
        let hotkey = version >= 2 ? #","toggleHotkey":{"keyCode":97,"modifiers":0}"# : ""
        store(json: #"{"version":\#(version),"configuration":"# + configuration + hotkey + "}")
        let store = SettingsStore(defaults: defaults)

        store.save(store.load())

        let envelope = try storedEnvelope()
        #expect(envelope["version"] as? Int == 4)
        #expect(envelope["toggleHotkey"] is [String: Any])
        #expect((envelope["profiles"] as? [Any])?.isEmpty == true)
        #expect(envelope["activeProfileID"] is NSNull)
        let storedConfiguration = try #require(envelope["configuration"] as? [String: Any])
        #expect(storedConfiguration["modifiers"] as? [String] == [])
        #expect(storedConfiguration["positionOffset"] as? Int == 0)
        #expect(store.load() == AppSettings(configuration: Self.legacyConfiguration, toggleHotkey: .f6))
    }

    @Test func versionThreeMigratesWithItsModifiersNoOffsetAndNoProfiles() {
        // A literal blob in the version 3 format, so the test does not depend on today's encoder.
        store(
            json: #"{"version":3,"configuration":{"clickType":"left","#
                + #""interval":{"hours":0,"minutes":0,"seconds":0,"milliseconds":100,"jitterMilliseconds":0},"#
                + #""target":{"kind":"fixed","x":12,"y":34},"stopCondition":{"kind":"never"},"#
                + #""modifiers":["shift","command"]},"#
                + #""toggleHotkey":{"keyCode":40,"modifiers":6144,"keyLabel":"K"}}"#)

        let loaded = SettingsStore(defaults: defaults).load()

        var expected = AppSettings(configuration: .default, toggleHotkey: Self.customHotkey)
        expected.configuration.target = .fixed(CGPoint(x: 12, y: 34))
        expected.configuration.modifiers = [.shift, .command]
        #expect(loaded == expected)
        #expect(loaded.configuration.positionOffset == 0)
        #expect(loaded.profiles.isEmpty)
        #expect(loaded.activeProfileID == nil)
        #expect(loaded.toggleHotkey.keyLabel == "K")
    }

    @Test func versionThreeWithAnInvalidShortcutFallsBackToF6AndKeepsTheConfiguration() {
        store(
            json: #"{"version":3,"configuration":{"clickType":"double","#
                + #""interval":{"hours":0,"minutes":0,"seconds":0,"milliseconds":100,"jitterMilliseconds":0},"#
                + #""target":{"kind":"currentCursor"},"stopCondition":{"kind":"never"},"modifiers":[]},"#
                + #""toggleHotkey":{"keyCode":53,"modifiers":0}}"#)
        var expected = AppSettings.default
        expected.configuration.clickType = .double
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

    // MARK: - Version 4

    @Test func versionFourLiteralLoadsEverything() {
        // A literal blob in the version 4 format, so the test does not depend on today's encoder.
        let configuration =
            #"{"clickType":"right","#
            + #""interval":{"hours":0,"minutes":0,"seconds":0,"milliseconds":250,"jitterMilliseconds":20},"#
            + #""target":{"kind":"sequence","points":[{"x":10,"y":20,"delayMilliseconds":100},"#
            + #"{"x":-300,"y":40.5,"delayMilliseconds":1500}]},"#
            + #""stopCondition":{"kind":"afterClicks","clicks":10},"modifiers":["option"],"positionOffset":5}"#
        let profiles =
            #"[{"id":"6F1C1B5E-2D7A-4C3B-9E8F-0123456789AB","name":"Game","configuration":"# + configuration + "},"
            + #"{"id":"0A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D","name":"Work","configuration":"#
            + Self.defaultConfigurationJSON + "}]"
        store(
            json: Self.versionFourJSON(
                configuration: configuration, hotkey: #"{"keyCode":40,"modifiers":6144,"keyLabel":"K"}"#,
                profiles: profiles, activeProfileID: #""0A1B2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D""#))

        let loaded = SettingsStore(defaults: defaults).load()

        #expect(loaded.configuration == Self.sequenceConfiguration)
        #expect(loaded.toggleHotkey == Self.customHotkey)
        #expect(loaded.profiles == Self.customProfiles)
        #expect(loaded.activeProfileID == Self.workProfileID)
    }

    @Test func versionFourWithANullActiveProfileLoadsNoActiveProfile() throws {
        store(
            json: Self.versionFourJSON(
                configuration: Self.rightClickConfigurationJSON, profiles: try Self.json(of: Self.customProfiles)))
        let loaded = SettingsStore(defaults: defaults).load()
        #expect(loaded.configuration.clickType == .right)
        #expect(loaded.profiles == Self.customProfiles)
        #expect(loaded.activeProfileID == nil)
    }

    @Test func danglingActiveProfileIDLoadsAsNil() throws {
        store(
            json: Self.versionFourJSON(
                configuration: Self.rightClickConfigurationJSON, profiles: try Self.json(of: Self.customProfiles),
                activeProfileID: #""11111111-2222-4333-8444-555555555555""#))

        let loaded = SettingsStore(defaults: defaults).load()

        #expect(loaded.configuration.clickType == .right)
        #expect(loaded.profiles == Self.customProfiles)
        #expect(loaded.activeProfileID == nil)
        #expect(loaded.activeProfile == nil)
    }

    @Test func activeProfileIDWithoutAnyProfilesLoadsAsNil() {
        store(
            json: Self.versionFourJSON(
                configuration: Self.rightClickConfigurationJSON,
                activeProfileID: #""6F1C1B5E-2D7A-4C3B-9E8F-0123456789AB""#))
        let loaded = SettingsStore(defaults: defaults).load()
        #expect(loaded.configuration.clickType == .right)
        #expect(loaded.activeProfileID == nil)
    }

    @Test func profileNamesAreRepairedOnLoad() throws {
        let profiles = [
            Profile(id: Self.gameProfileID, name: "  Game  ", configuration: .default),
            Profile(id: Self.workProfileID, name: "game", configuration: .default),
            Profile(name: "", configuration: .default),
            Profile(name: String(repeating: "x", count: 45), configuration: .default),
        ]
        store(
            json: Self.versionFourJSON(
                configuration: Self.defaultConfigurationJSON, profiles: try Self.json(of: profiles),
                activeProfileID: #""\#(Self.workProfileID.uuidString)""#))

        let loaded = SettingsStore(defaults: defaults).load()

        #expect(loaded.profiles.map(\.name) == ["Game", "game 2", "Profile", String(repeating: "x", count: 40)])
        #expect(loaded.profiles.map(\.id) == profiles.map(\.id))
        // Repairing a name keeps the profile's identity, so it stays active.
        #expect(loaded.activeProfileID == Self.workProfileID)
    }

    @Test func profilesBeyondFiftyAreDroppedOnLoad() throws {
        let profiles = (1...55).map { Profile(name: "P\($0)", configuration: .default) }
        store(
            json: Self.versionFourJSON(
                configuration: Self.defaultConfigurationJSON, profiles: try Self.json(of: profiles),
                activeProfileID: #""\#(profiles[52].id.uuidString)""#))

        let loaded = SettingsStore(defaults: defaults).load()

        #expect(loaded.profiles == Array(profiles.prefix(50)))
        // The active profile was dropped with the others, so nothing is active.
        #expect(loaded.activeProfileID == nil)
    }

    @Test(arguments: [
        // No profiles key.
        #"{"version":4,"configuration":CONFIG,"toggleHotkey":{"keyCode":97,"modifiers":0},"activeProfileID":null}"#,
        // No activeProfileID key: version 4 always writes it, as null when no profile is active.
        #"{"version":4,"configuration":CONFIG,"toggleHotkey":{"keyCode":97,"modifiers":0},"profiles":[]}"#,
        // A profile without a configuration.
        #"{"version":4,"configuration":CONFIG,"toggleHotkey":{"keyCode":97,"modifiers":0},"#
            + #""profiles":[{"id":"6F1C1B5E-2D7A-4C3B-9E8F-0123456789AB","name":"Game"}],"activeProfileID":null}"#,
        // A profile with an id that is not a UUID.
        #"{"version":4,"configuration":CONFIG,"toggleHotkey":{"keyCode":97,"modifiers":0},"#
            + #""profiles":[{"id":"game","name":"Game","configuration":CONFIG}],"activeProfileID":null}"#,
        // An active id that is not a UUID.
        #"{"version":4,"configuration":CONFIG,"toggleHotkey":{"keyCode":97,"modifiers":0},"profiles":[],"#
            + #""activeProfileID":"game"}"#,
    ])
    func malformedVersionFourEnvelopeLoadsTheDefault(template: String) {
        store(json: template.replacingOccurrences(of: "CONFIG", with: Self.rightClickConfigurationJSON))
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func versionFourConfigurationWithoutPositionOffsetLoadsTheDefault() {
        // Version 4 always stores the offset; a configuration without it is not version 4 and is not guessed at.
        let configuration = Self.rightClickConfigurationJSON.replacingOccurrences(
            of: #","positionOffset":0"#, with: "")
        store(json: Self.versionFourJSON(configuration: configuration))
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [3, 4])
    func unknownTargetKindLoadsTheDefault(version: Int) {
        let configuration = Self.rightClickConfigurationJSON.replacingOccurrences(
            of: #"{"kind":"currentCursor"}"#, with: #"{"kind":"window","id":3}"#)
        let json =
            version == 4
            ? Self.versionFourJSON(configuration: configuration)
            : #"{"version":3,"configuration":"# + configuration + #","toggleHotkey":{"keyCode":40,"modifiers":6144}}"#
        store(json: json)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func unknownTargetKindInAProfileLoadsTheDefault() {
        let profileConfiguration = Self.defaultConfigurationJSON.replacingOccurrences(
            of: #"{"kind":"currentCursor"}"#, with: #"{"kind":"window"}"#)
        let profiles =
            #"[{"id":"6F1C1B5E-2D7A-4C3B-9E8F-0123456789AB","name":"Game","configuration":"#
            + profileConfiguration + "}]"
        store(json: Self.versionFourJSON(configuration: Self.rightClickConfigurationJSON, profiles: profiles))
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

    @Test(arguments: [2, 3, 4])
    func malformedConfigurationLoadsTheDefault(version: Int) {
        store(
            json: #"{"version":\#(version),"configuration":{"clickType":"triple"},"#
                + #""toggleHotkey":{"keyCode":40,"modifiers":6144},"profiles":[],"activeProfileID":null}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [2, 3, 4])
    func envelopeWithoutAHotkeyLoadsTheDefault(version: Int) throws {
        // Versions 2 to 4 always have a shortcut; an envelope without one must not be guessed at.
        let configuration = try Self.json(of: Self.customConfiguration)
        store(
            json: #"{"version":\#(version),"configuration":"# + configuration
                + #","profiles":[],"activeProfileID":null}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func malformedHotkeyLoadsTheDefault() throws {
        let configuration = try Self.json(of: Self.customConfiguration)
        store(json: Self.versionFourJSON(configuration: configuration, hotkey: #"{"keyCode":"F6"}"#))
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [3, 4])
    func malformedModifiersLoadTheDefault(version: Int) {
        store(
            json: #"{"version":\#(version),"configuration":{"clickType":"right","#
                + #""interval":{"hours":0,"minutes":0,"seconds":0,"milliseconds":100,"jitterMilliseconds":0},"#
                + #""target":{"kind":"currentCursor"},"stopCondition":{"kind":"never"},"#
                + #""modifiers":"shift","positionOffset":0},"#
                + #""toggleHotkey":{"keyCode":97,"modifiers":0},"profiles":[],"activeProfileID":null}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [
        #"{"keyCode":53,"modifiers":0}"#,  // Esc, reserved for the emergency stop
        #"{"keyCode":40,"modifiers":0}"#,  // K without a modifier
        #"{"keyCode":40,"modifiers":512}"#,  // ⇧K
        #"{"keyCode":56,"modifiers":256}"#,  // Shift key on its own
        #"{"keyCode":97,"modifiers":1024}"#,  // F6 with Caps Lock, not a shortcut modifier
    ])
    func invalidStoredShortcutFallsBackToF6AndKeepsTheRest(hotkeyJSON: String) throws {
        let configuration = try Self.json(of: Self.customConfiguration)
        store(
            json: Self.versionFourJSON(
                configuration: configuration, hotkey: hotkeyJSON, profiles: try Self.json(of: Self.customProfiles),
                activeProfileID: #""\#(Self.gameProfileID.uuidString)""#))
        #expect(
            SettingsStore(defaults: defaults).load()
                == AppSettings(
                    configuration: Self.customConfiguration, profiles: Self.customProfiles,
                    activeProfileID: Self.gameProfileID))
    }

    @Test(arguments: [0, SettingsStore.currentVersion + 1, 99])
    func unknownVersionLoadsTheDefault(version: Int) throws {
        // A valid body under a version this build does not understand must not be guessed at.
        let configuration = try Self.json(of: Self.customConfiguration)
        store(
            json: #"{"version":\#(version),"configuration":"# + configuration
                + #","toggleHotkey":{"keyCode":40,"modifiers":6144},"profiles":[],"activeProfileID":null}"#)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    // MARK: - Format

    @Test func savesAVersionFourJSONEnvelope() throws {
        SettingsStore(defaults: defaults).save(Self.customSettings)
        let envelope = try storedEnvelope()
        #expect(envelope["version"] as? Int == 4)
        #expect(SettingsStore.currentVersion == 4)
        #expect(Set(envelope.keys) == ["version", "configuration", "toggleHotkey", "profiles", "activeProfileID"])
        let configuration = try #require(envelope["configuration"] as? [String: Any])
        #expect(configuration["clickType"] as? String == "double")
        // Menu order (⌃⌥⇧⌘), whatever order the set was built in.
        #expect(configuration["modifiers"] as? [String] == ["shift", "command"])
        #expect(configuration["positionOffset"] as? Int == 30)
        #expect(envelope["activeProfileID"] as? String == Self.gameProfileID.uuidString)
        let profiles = try #require(envelope["profiles"] as? [[String: Any]])
        #expect(profiles.map { Set($0.keys) } == [["id", "name", "configuration"], ["id", "name", "configuration"]])
        #expect(profiles.map { $0["name"] as? String } == ["Game", "Work"])
        let sequence = try #require(profiles[0]["configuration"] as? [String: Any])
        let target = try #require(sequence["target"] as? [String: Any])
        #expect(target["kind"] as? String == "sequence")
        let points = try #require(target["points"] as? [[String: Any]])
        #expect(points.first.map { Set($0.keys) } == ["x", "y", "delayMilliseconds"])
        let hotkey = try #require(envelope["toggleHotkey"] as? [String: Any])
        #expect(hotkey["keyCode"] as? Int == kVK_ANSI_K)
        #expect(hotkey["modifiers"] as? Int == controlKey | optionKey)
        #expect(hotkey["keyLabel"] as? String == "K")
    }

    @Test func savesNoActiveProfileAsAnExplicitNull() throws {
        SettingsStore(defaults: defaults).save(.default)
        let envelope = try storedEnvelope()
        #expect(envelope["activeProfileID"] is NSNull)
        #expect((envelope["profiles"] as? [Any])?.isEmpty == true)
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
