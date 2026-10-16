/// The time between two clicks, as entered by the user, plus an optional random jitter.
///
/// Components are stored exactly as entered so the UI can round-trip them. Use `duration` for scheduling: it ignores
/// negative components, saturates instead of overflowing and never returns less than 1 ms.
///
/// ## Jitter
/// The scheduler adds `jitterOffset(using:)` to each absolute deadline (`start + n × duration + offset`). Because the
/// offsets of two consecutive ticks are independent, the real gap between them is
/// `duration + offset(n + 1) - offset(n)`, which is at least `duration - 2 × jitter`. To guarantee that gap never drops
/// to zero or below, the jitter actually applied is capped at `(duration - 1 ms) / 2` (see
/// `effectiveJitterMilliseconds`). At the 1 ms minimum, jitter is therefore disabled.
struct ClickInterval: Sendable, Codable, Equatable {
    /// The shortest interval the engine will ever schedule.
    static let minimumMilliseconds = 1

    /// Whole hours. Negative values are treated as zero.
    var hours: Int
    /// Whole minutes. Negative values are treated as zero.
    var minutes: Int
    /// Whole seconds. Negative values are treated as zero.
    var seconds: Int
    /// Whole milliseconds. Negative values are treated as zero.
    var milliseconds: Int
    /// The requested random jitter, ± this many milliseconds. Negative values are treated as zero.
    var jitterMilliseconds: Int

    // Explicit keys: this type is part of the persisted settings schema, so renaming a property must not silently
    // change the stored JSON.
    private enum CodingKeys: String, CodingKey {
        case hours
        case minutes
        case seconds
        case milliseconds
        case jitterMilliseconds
    }

    /// Creates an interval from its components. Every component defaults to zero.
    init(hours: Int = 0, minutes: Int = 0, seconds: Int = 0, milliseconds: Int = 0, jitterMilliseconds: Int = 0) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.milliseconds = milliseconds
        self.jitterMilliseconds = jitterMilliseconds
    }

    /// The sum of all non-negative components in milliseconds, saturating at `Int.max`. Not clamped to the minimum.
    var totalMilliseconds: Int {
        let parts = [
            (hours, 3_600_000),
            (minutes, 60_000),
            (seconds, 1_000),
            (milliseconds, 1),
        ]
        var total = 0
        for (value, scale) in parts {
            let (scaled, multiplyOverflow) = max(0, value).multipliedReportingOverflow(by: scale)
            let (sum, addOverflow) = total.addingReportingOverflow(scaled)
            if multiplyOverflow || addOverflow {
                return Int.max
            }
            total = sum
        }
        return total
    }

    /// The interval to schedule, never shorter than 1 ms.
    var duration: Duration {
        .milliseconds(clampedMilliseconds)
    }

    /// The jitter actually applied, in milliseconds: the requested jitter capped at `(duration - 1 ms) / 2` so that
    /// consecutive deadlines always stay at least 1 ms apart.
    var effectiveJitterMilliseconds: Int {
        let cap = (clampedMilliseconds - Self.minimumMilliseconds) / 2
        return min(max(0, jitterMilliseconds), cap)
    }

    /// Returns a random offset in `-effectiveJitterMilliseconds...effectiveJitterMilliseconds` (whole milliseconds)
    /// to add to one tick's absolute deadline.
    ///
    /// Pass a seeded generator in tests to make the sequence deterministic. When jitter is disabled this returns
    /// `.zero` without consuming randomness.
    func jitterOffset(using generator: inout some RandomNumberGenerator) -> Duration {
        let jitter = effectiveJitterMilliseconds
        guard jitter > 0 else {
            return .zero
        }
        return .milliseconds(Int.random(in: -jitter...jitter, using: &generator))
    }

    /// Returns a random jitter offset using the system random number generator.
    func jitterOffset() -> Duration {
        var generator = SystemRandomNumberGenerator()
        return jitterOffset(using: &generator)
    }

    private var clampedMilliseconds: Int {
        max(Self.minimumMilliseconds, totalMilliseconds)
    }
}
