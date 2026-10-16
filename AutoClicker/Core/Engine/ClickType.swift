/// The mouse click the engine posts on every tick.
///
/// The raw values are persisted by `SettingsStore`, so they must never change.
enum ClickType: String, Sendable, Codable, CaseIterable {
    /// A primary-button down/up pair.
    case left
    /// A secondary-button down/up pair.
    case right
    /// A center-button (`.otherMouse*`) down/up pair.
    case middle
    /// Two primary-button down/up pairs; the second pair carries click state 2.
    case double
}
