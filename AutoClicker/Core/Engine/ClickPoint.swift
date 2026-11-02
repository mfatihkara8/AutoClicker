import CoreGraphics

/// One step of a click sequence: a point and the wait before its click (SPEC §7.2, ADR-011).
///
/// The point is in CG global space (top-left origin of the main display), like `ClickTarget.fixed`. Conversion from
/// AppKit coordinates happens only in `ScreenGeometry` (ADR-006).
///
/// `delayMilliseconds` is stored exactly as entered, so the editor can round-trip it. Use `delay` for scheduling: it
/// is always inside `delayRange`.
struct ClickPoint: Sendable, Equatable {
    /// The supported wait before a point's click, in milliseconds: 1 ms to 24 h.
    static let delayRange = 1...86_400_000

    /// Where this step clicks, in CG global space.
    var point: CGPoint
    /// The wait before this point's click, in milliseconds. Values outside `delayRange` are clamped by `delay`.
    var delayMilliseconds: Int

    /// The wait before this point's click, clamped to `delayRange`.
    var delay: Duration {
        .milliseconds(min(max(delayMilliseconds, Self.delayRange.lowerBound), Self.delayRange.upperBound))
    }
}

// Custom coding keeps each point flat (`{"x":…,"y":…,"delayMilliseconds":…}`), matching the flat shape of
// `ClickTarget.fixed`, instead of nesting the synthesized `CGPoint` array.
extension ClickPoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case delayMilliseconds
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        point = CGPoint(x: x, y: y)
        delayMilliseconds = try container.decode(Int.self, forKey: .delayMilliseconds)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(point.x, forKey: .x)
        try container.encode(point.y, forKey: .y)
        try container.encode(delayMilliseconds, forKey: .delayMilliseconds)
    }
}
