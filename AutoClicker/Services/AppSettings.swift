import Foundation

/// Everything `SettingsStore` persists: the working click configuration, the start/stop shortcut and the profiles
/// (ADR-007, ADR-008, ADR-013).
struct AppSettings: Sendable, Equatable {
    /// The click configuration with F6 as the start/stop shortcut and no profiles, used when nothing usable is stored.
    static let `default` = AppSettings(configuration: .default, toggleHotkey: .f6)

    /// The working configuration: what the Click tab edits and what Start uses. Separate from the profiles.
    var configuration: ClickConfiguration
    /// The global shortcut that starts and stops clicking. The ESC emergency stop is fixed and not stored.
    var toggleHotkey: Hotkey
    /// The saved profiles, in the user's order. `SettingsStore` loads them with the name rules of `Profile` restored.
    var profiles: [Profile]
    /// The profile last applied or saved, or `nil` when none is. `SettingsStore` loads an id that matches no profile
    /// as `nil`.
    var activeProfileID: UUID?

    init(
        configuration: ClickConfiguration, toggleHotkey: Hotkey = .f6, profiles: [Profile] = [],
        activeProfileID: UUID? = nil
    ) {
        self.configuration = configuration
        self.toggleHotkey = toggleHotkey
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    /// The profile whose id is `activeProfileID`, or `nil` when none matches.
    var activeProfile: Profile? {
        guard let activeProfileID else { return nil }
        return profiles.first { $0.id == activeProfileID }
    }
}
