/// When a click run ends on its own.
enum StopCondition: Sendable, Equatable {
    /// Run until the user, a hotkey or a failsafe stops it.
    case never
    /// Stop once this many clicks have been posted. A limit of zero or less is satisfied immediately.
    case afterClicks(Int)
    /// Stop once this much time has elapsed since the run started. A limit of zero or less is satisfied immediately.
    case afterDuration(Duration)

    /// Returns whether the run should stop.
    ///
    /// The engine calls this after each posted click with the updated count and the time since the run started.
    /// Limits are inclusive: `.afterClicks(10)` is satisfied at exactly 10 clicks.
    func isSatisfied(clicks: Int, elapsed: Duration) -> Bool {
        switch self {
        case .never:
            return false
        case .afterClicks(let limit):
            return clicks >= limit
        case .afterDuration(let limit):
            return elapsed >= limit
        }
    }
}

// `Duration` is `Codable` since macOS 13, but it encodes as an opaque `[high, low]` pair of attosecond words, and the
// synthesized enum coding would add `{"afterDuration":{"_0":…}}` nesting. This flat shape is readable and lossless:
// `{"kind":"afterDuration","seconds":2,"attoseconds":500000000000000000}`.
extension StopCondition: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case clicks
        case seconds
        case attoseconds
    }

    private enum Kind: String, Codable {
        case never
        case afterClicks
        case afterDuration
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .never:
            self = .never
        case .afterClicks:
            self = .afterClicks(try container.decode(Int.self, forKey: .clicks))
        case .afterDuration:
            let seconds = try container.decode(Int64.self, forKey: .seconds)
            let attoseconds = try container.decode(Int64.self, forKey: .attoseconds)
            self = .afterDuration(Duration(secondsComponent: seconds, attosecondsComponent: attoseconds))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .never:
            try container.encode(Kind.never, forKey: .kind)
        case .afterClicks(let limit):
            try container.encode(Kind.afterClicks, forKey: .kind)
            try container.encode(limit, forKey: .clicks)
        case .afterDuration(let limit):
            try container.encode(Kind.afterDuration, forKey: .kind)
            try container.encode(limit.components.seconds, forKey: .seconds)
            try container.encode(limit.components.attoseconds, forKey: .attoseconds)
        }
    }
}
