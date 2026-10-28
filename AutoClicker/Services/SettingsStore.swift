import Foundation
import os

/// Loads and saves the user's `AppSettings` in `UserDefaults` as versioned JSON (ADR-007, ADR-008, ADR-009).
///
/// The value is stored as `Data` under one key, wrapped in an envelope:
/// `{"version": 3, "configuration": {...}, "toggleHotkey": {...}}`. The version lets a later build migrate or reject
/// settings written by another build instead of misreading them.
///
/// ## Versions
/// - 1: `{"version": 1, "configuration": {...}}`. Loaded with F6 as the start/stop shortcut.
/// - 2: adds `toggleHotkey`, the user-configurable start/stop shortcut.
/// - 3: adds `configuration.modifiers`, the modifier keys held for every click. Written by this build. Versions 1 and
///   2 load with no modifiers.
///
/// ## Concurrency
/// The class is `@MainActor` rather than `Sendable`. `UserDefaults` is documented as thread-safe, but the SDK does
/// not mark it `Sendable`, so a `Sendable` store would need `@unchecked`. Its only caller, the `@MainActor` view
/// model, already lives on the main actor, and a load or save is a small JSON round trip, so main-actor isolation
/// costs nothing and keeps the compiler's checking intact.
///
/// Saves are written immediately. Debouncing rapid edits is the view model's job.
@MainActor
final class SettingsStore {
    /// The schema version written by `save(_:)`.
    nonisolated static let currentVersion = 3

    private let defaults: UserDefaults
    private let key: String
    private let logger = Logger(subsystem: "AutoClicker", category: "SettingsStore")

    /// Creates a store.
    ///
    /// - Parameters:
    ///   - defaults: Where the settings live. The app passes `.standard`; tests pass a throwaway suite.
    ///   - key: The single `UserDefaults` key that holds the envelope. Unchanged since version 1, so older settings
    ///     are found and migrated.
    init(defaults: UserDefaults, key: String = "clickConfiguration") {
        self.defaults = defaults
        self.key = key
    }

    /// Returns the saved settings, or `.default` when nothing usable is stored.
    ///
    /// Version 1 settings keep their configuration and get F6 as the start/stop shortcut. Versions 1 and 2 load with
    /// no modifiers, since plain clicks were all they could post. A missing value, corrupt
    /// data, a malformed body or a version this build does not know all fall back to `.default`. A well-formed
    /// shortcut that `ShortcutValidator` rejects is replaced by F6. Settings are never worth crashing over, and the
    /// next `save(_:)` overwrites the bad value.
    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        let decoder = JSONDecoder()
        let header: VersionHeader
        do {
            header = try decoder.decode(VersionHeader.self, from: data)
        } catch {
            logger.error("Ignoring unreadable settings: \(error.localizedDescription, privacy: .public)")
            return .default
        }

        do {
            switch header.version {
            case Self.currentVersion:
                let envelope = try decoder.decode(Envelope.self, from: data)
                return AppSettings(
                    configuration: envelope.configuration, toggleHotkey: validated(envelope.toggleHotkey))
            case 2:
                // Version 2 predates modifier clicks.
                let envelope = try decoder.decode(EnvelopeV2.self, from: data)
                return AppSettings(
                    configuration: envelope.configuration.migrated, toggleHotkey: validated(envelope.toggleHotkey))
            case 1:
                // Version 1 also predates the configurable shortcut, when the start/stop hotkey was always F6.
                let envelope = try decoder.decode(EnvelopeV1.self, from: data)
                return AppSettings(configuration: envelope.configuration.migrated, toggleHotkey: .f6)
            default:
                logger.error("Ignoring settings with unknown version \(header.version, privacy: .public)")
                return .default
            }
        } catch {
            logger.error("Ignoring malformed settings: \(error.localizedDescription, privacy: .public)")
            return .default
        }
    }

    /// Persists `settings` immediately as a version `currentVersion` envelope.
    ///
    /// Encoding cannot fail in practice. If it ever does, the previously stored value is kept and the failure is
    /// logged rather than thrown, because the caller has no meaningful way to recover.
    func save(_ settings: AppSettings) {
        let envelope = Envelope(
            version: Self.currentVersion, configuration: settings.configuration, toggleHotkey: settings.toggleHotkey)
        do {
            defaults.set(try JSONEncoder().encode(envelope), forKey: key)
        } catch {
            logger.error("Could not encode settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns `hotkey`, or F6 when the recorder could never have accepted it (for example Esc, which would clash with
    /// the emergency stop). Only the shortcut is replaced; the click configuration next to it is still good.
    private func validated(_ hotkey: Hotkey) -> Hotkey {
        guard let rejection = ShortcutValidator.rejection(for: hotkey) else { return hotkey }
        logger.error("Replacing invalid stored shortcut with F6: \(String(describing: rejection), privacy: .public)")
        return .f6
    }

    // MARK: - Schema

    /// Just the version, decoded first so that an unknown schema is recognized before its body is interpreted.
    private struct VersionHeader: Decodable {
        let version: Int
    }

    /// The stored shape of the current schema version (3).
    private struct Envelope: Codable {
        let version: Int
        let configuration: ClickConfiguration
        let toggleHotkey: Hotkey
    }

    /// The stored shape of version 2, kept only to migrate it.
    private struct EnvelopeV2: Decodable {
        let version: Int
        let configuration: ConfigurationV2
        let toggleHotkey: Hotkey
    }

    /// The stored shape of version 1, kept only to migrate it.
    private struct EnvelopeV1: Decodable {
        let version: Int
        let configuration: ConfigurationV2
    }

    /// The click configuration as versions 1 and 2 stored it: everything but `modifiers`.
    ///
    /// Decoded separately because `ClickConfiguration` requires every current key; that keeps a version 3 envelope
    /// without modifiers malformed instead of silently guessed at.
    private struct ConfigurationV2: Decodable {
        let clickType: ClickType
        let interval: ClickInterval
        let target: ClickTarget
        let stopCondition: StopCondition

        /// The same configuration with no modifiers held.
        var migrated: ClickConfiguration {
            ClickConfiguration(
                clickType: clickType, interval: interval, target: target, stopCondition: stopCondition, modifiers: [])
        }
    }
}
