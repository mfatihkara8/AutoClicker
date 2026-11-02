/// Editing glue between the Target section's offset field and `ClickConfiguration.positionOffset`.
///
/// The setter clamps to `ClickConfiguration.positionOffsetRange`, so a typed value can never store an unsupported
/// radius. The getter shows the stored value clamped the same way, as older or corrupt data could hold anything.
struct PositionOffsetEditor: Equatable {
    /// The edited radius in points, as stored.
    private(set) var positionOffset: Int

    init(positionOffset: Int) {
        self.positionOffset = positionOffset
    }

    /// The radius in points, inside `ClickConfiguration.positionOffsetRange`. 0 means off.
    var points: Int {
        get { positionOffset.clamped(to: ClickConfiguration.positionOffsetRange) }
        set { positionOffset = newValue.clamped(to: ClickConfiguration.positionOffsetRange) }
    }
}
