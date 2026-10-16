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

    private func storedEnvelope() throws -> [String: Any] {
        let data = try #require(defaults.data(forKey: key))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Round trip

    @Test func roundTripsANonDefaultConfiguration() {
        let store = SettingsStore(defaults: defaults)
        store.save(Self.customConfiguration)
        #expect(store.load() == Self.customConfiguration)
    }

    @Test(arguments: ClickType.allCases)
    func roundTripsEveryClickType(clickType: ClickType) {
        let store = SettingsStore(defaults: defaults)
        var configuration = ClickConfiguration.default
        configuration.clickType = clickType
        store.save(configuration)
        #expect(store.load() == configuration)
    }

    @Test(arguments: [
        StopCondition.never,
        .afterClicks(1_000),
        .afterDuration(.seconds(90)),
        .afterDuration(.milliseconds(1_500)),
    ])
    func roundTripsEveryStopCondition(stopCondition: StopCondition) {
        let store = SettingsStore(defaults: defaults)
        var configuration = ClickConfiguration.default
        configuration.stopCondition = stopCondition
        store.save(configuration)
        #expect(store.load() == configuration)
    }

    @Test(arguments: [ClickTarget.currentCursor, .fixed(CGPoint(x: 0, y: 0)), .fixed(CGPoint(x: -2560, y: 42.25))])
    func roundTripsEveryTarget(target: ClickTarget) {
        let store = SettingsStore(defaults: defaults)
        var configuration = ClickConfiguration.default
        configuration.target = target
        store.save(configuration)
        #expect(store.load() == configuration)
    }

    @Test func laterSaveReplacesTheEarlierOne() {
        let store = SettingsStore(defaults: defaults)
        store.save(Self.customConfiguration)
        store.save(.default)
        #expect(store.load() == .default)
    }

    // MARK: - Fallbacks

    @Test func missingValueLoadsTheDefault() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.load() == .default)
    }

    @Test func corruptDataLoadsTheDefault() {
        defaults.set(Data("not json {".utf8), forKey: key)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func wrongValueTypeLoadsTheDefault() {
        defaults.set("a string, not data", forKey: key)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func envelopeWithoutVersionLoadsTheDefault() throws {
        let configuration = try JSONEncoder().encode(Self.customConfiguration)
        let json = #"{"configuration":"# + String(decoding: configuration, as: UTF8.self) + "}"
        defaults.set(Data(json.utf8), forKey: key)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test func malformedConfigurationLoadsTheDefault() {
        let json = #"{"version":1,"configuration":{"clickType":"triple"}}"#
        defaults.set(Data(json.utf8), forKey: key)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    @Test(arguments: [0, SettingsStore.currentVersion + 1, 99])
    func unknownVersionLoadsTheDefault(version: Int) throws {
        // A valid configuration under a version this build does not understand must not be guessed at.
        let configuration = try JSONEncoder().encode(Self.customConfiguration)
        let json = #"{"version":\#(version),"configuration":"# + String(decoding: configuration, as: UTF8.self) + "}"
        defaults.set(Data(json.utf8), forKey: key)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    // MARK: - Format

    @Test func savesAVersionedJSONEnvelope() throws {
        SettingsStore(defaults: defaults).save(Self.customConfiguration)
        let envelope = try storedEnvelope()
        #expect(envelope["version"] as? Int == 1)
        #expect(SettingsStore.currentVersion == 1)
        let configuration = try #require(envelope["configuration"] as? [String: Any])
        #expect(configuration["clickType"] as? String == "double")
    }

    @Test func usesTheInjectedKey() {
        let store = SettingsStore(defaults: defaults, key: "otherKey")
        store.save(Self.customConfiguration)
        #expect(defaults.data(forKey: "otherKey") != nil)
        #expect(defaults.data(forKey: key) == nil)
        #expect(SettingsStore(defaults: defaults).load() == .default)
    }

    // MARK: - SC-8

    @Test func freshStoreOnTheSameSuiteLoadsWhatAnotherSaved() throws {
        SettingsStore(defaults: defaults).save(Self.customConfiguration)
        // A new `UserDefaults` instance on the same suite stands in for a relaunched app.
        let relaunchedDefaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(SettingsStore(defaults: relaunchedDefaults).load() == Self.customConfiguration)
    }
}
