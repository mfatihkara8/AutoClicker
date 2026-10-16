/// Everything `SettingsStore` persists: the click configuration and the start/stop shortcut (ADR-007, ADR-008).
struct AppSettings: Sendable, Equatable {
    /// The click configuration with F6 as the start/stop shortcut, used when nothing usable is stored.
    static let `default` = AppSettings(configuration: .default, toggleHotkey: .f6)

    /// The settings for the next run.
    var configuration: ClickConfiguration
    /// The global shortcut that starts and stops clicking. The ESC emergency stop is fixed and not stored.
    var toggleHotkey: Hotkey

    init(configuration: ClickConfiguration, toggleHotkey: Hotkey = .f6) {
        self.configuration = configuration
        self.toggleHotkey = toggleHotkey
    }
}
