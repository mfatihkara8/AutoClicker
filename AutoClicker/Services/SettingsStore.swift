import Foundation
import os

/// Loads and saves the user's `ClickConfiguration` in `UserDefaults` as versioned JSON (ADR-007).
///
/// The value is stored as `Data` under one key, wrapped in an envelope: `{"version": 1, "configuration": {...}}`. The
/// version lets a later build migrate or reject settings written by another build instead of misreading them.
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
    nonisolated static let currentVersion = 1

    private let defaults: UserDefaults
    private let key: String
    private let logger = Logger(subsystem: "AutoClicker", category: "SettingsStore")

    /// Creates a store.
    ///
    /// - Parameters:
    ///   - defaults: Where the settings live. The app passes `.standard`; tests pass a throwaway suite.
    ///   - key: The single `UserDefaults` key that holds the envelope.
    init(defaults: UserDefaults, key: String = "clickConfiguration") {
        self.defaults = defaults
        self.key = key
    }

    /// Returns the saved configuration, or `.default` when nothing usable is stored.
    ///
    /// A missing value, corrupt data, a malformed configuration or a version this build does not know all fall back
    /// to `.default`. Settings are never worth crashing over, and the next `save(_:)` overwrites the bad value.
    func load() -> ClickConfiguration {
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

        switch header.version {
        case Self.currentVersion:
            do {
                return try decoder.decode(Envelope.self, from: data).configuration
            } catch {
                logger.error("Ignoring malformed settings: \(error.localizedDescription, privacy: .public)")
                return .default
            }
        // Migrations go here: decode an older schema and convert it to the current `ClickConfiguration`, for example
        // `case 1: return LegacyV1.decode(data).migrated()` once the current version becomes 2.
        default:
            logger.error("Ignoring settings with unknown version \(header.version, privacy: .public)")
            return .default
        }
    }

    /// Persists `configuration` immediately as a version `currentVersion` envelope.
    ///
    /// Encoding a `ClickConfiguration` cannot fail in practice. If it ever does, the previously stored value is kept
    /// and the failure is logged rather than thrown, because the caller has no meaningful way to recover.
    func save(_ configuration: ClickConfiguration) {
        do {
            let data = try JSONEncoder().encode(Envelope(version: Self.currentVersion, configuration: configuration))
            defaults.set(data, forKey: key)
        } catch {
            logger.error("Could not encode settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Schema

    /// Just the version, decoded first so that an unknown schema is recognized before its body is interpreted.
    private struct VersionHeader: Decodable {
        let version: Int
    }

    /// The stored shape of the current schema version.
    private struct Envelope: Codable {
        let version: Int
        let configuration: ClickConfiguration
    }
}
