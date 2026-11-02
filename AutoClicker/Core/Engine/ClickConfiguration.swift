/// Everything the engine needs for one click run. It is also the persisted settings value (ADR-007).
///
/// The ViewModel snapshots it on start and hands the copy to the engine, so it is a `Sendable` value type.
struct ClickConfiguration: Sendable, Codable, Equatable {
    /// Left click every 100 ms at the current cursor, until stopped.
    static let `default` = ClickConfiguration(
        clickType: .left,
        interval: ClickInterval(milliseconds: 100),
        target: .currentCursor,
        stopCondition: .never)

    /// The supported random position offset radius, in points (SPEC §7.1). 0 means off.
    static let positionOffsetRange = 0...200

    /// The click posted on every tick.
    var clickType: ClickType
    /// The time between ticks, including jitter. Not used for a `.sequence` target, whose points set their own delays,
    /// but its jitter still applies (ADR-011).
    var interval: ClickInterval
    /// Where each click lands.
    var target: ClickTarget
    /// When the run ends on its own.
    var stopCondition: StopCondition
    /// The modifier keys held for every click, whatever its type. Empty by default.
    var modifiers: ClickModifiers = []
    /// The radius, in points, of the random offset applied to each click on a fixed or sequence target (ADR-012).
    /// 0, the default, means off. Ignored for `.currentCursor`. Stored as entered; the supported values are
    /// `positionOffsetRange`.
    var positionOffset: Int = 0

    // Explicit keys: renaming a property must not silently change the persisted JSON. Schema changes go through the
    // version handled by `SettingsStore`. Every key is required, `modifiers` and `positionOffset` included: older
    // schemas without them are migrated by `SettingsStore`, not guessed at here.
    private enum CodingKeys: String, CodingKey {
        case clickType
        case interval
        case target
        case stopCondition
        case modifiers
        case positionOffset
    }
}
