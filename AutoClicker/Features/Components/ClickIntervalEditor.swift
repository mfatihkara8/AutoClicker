/// Editing glue between the interval card's fields and a `ClickInterval`.
///
/// Every setter clamps its input to a non-negative, bounded range, so neither a typed nor a stepped value can store a
/// negative component. The getters show what is stored, with negative values from older data shown as zero.
struct ClickIntervalEditor: Equatable {
    static let hoursRange = 0...999
    static let minutesRange = 0...59
    static let secondsRange = 0...59
    static let millisecondsRange = 0...999
    /// Up to ± one hour. The engine caps it further for short intervals (see `effectiveJitterMilliseconds`).
    static let jitterRange = 0...3_600_000

    /// The edited interval.
    private(set) var interval: ClickInterval

    init(interval: ClickInterval) {
        self.interval = interval
    }

    var hours: Int {
        get { max(0, interval.hours) }
        set { interval.hours = newValue.clamped(to: Self.hoursRange) }
    }

    var minutes: Int {
        get { max(0, interval.minutes) }
        set { interval.minutes = newValue.clamped(to: Self.minutesRange) }
    }

    var seconds: Int {
        get { max(0, interval.seconds) }
        set { interval.seconds = newValue.clamped(to: Self.secondsRange) }
    }

    var milliseconds: Int {
        get { max(0, interval.milliseconds) }
        set { interval.milliseconds = newValue.clamped(to: Self.millisecondsRange) }
    }

    var jitterMilliseconds: Int {
        get { max(0, interval.jitterMilliseconds) }
        set { interval.jitterMilliseconds = newValue.clamped(to: Self.jitterRange) }
    }

    /// The jitter the engine will actually apply, in milliseconds.
    var effectiveJitterMilliseconds: Int {
        interval.effectiveJitterMilliseconds
    }

    /// Whether the requested jitter is larger than what the engine applies for this interval.
    var isJitterCapped: Bool {
        jitterMilliseconds > effectiveJitterMilliseconds
    }

    /// Whether the entered interval is shorter than the 1 ms minimum, so the engine raises it to 1 ms.
    var isRaisedToMinimum: Bool {
        interval.totalMilliseconds < ClickInterval.minimumMilliseconds
    }
}
