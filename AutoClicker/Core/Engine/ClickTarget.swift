import CoreGraphics

/// Where each click lands.
///
/// Points are in CG global space (top-left origin of the main display). Conversion from AppKit coordinates
/// happens only in `ScreenGeometry` (ADR-006).
enum ClickTarget: Sendable, Equatable {
    /// The most points a sequence holds (SPEC §7.2). Decoding keeps only the first `maxSequencePoints` points.
    static let maxSequencePoints = 50

    /// Click wherever the cursor is when the tick fires.
    case currentCursor
    /// Click at a fixed point in CG global space.
    case fixed(CGPoint)
    /// Click the points in turn, each after its own delay, wrapping around after the last one (ADR-011).
    ///
    /// A usable sequence has 1 to `maxSequencePoints` points. An empty one is a valid value to edit and store, but it
    /// cannot start a run.
    case sequence([ClickPoint])
}

// Custom coding keeps the persisted JSON flat and readable (`{"kind":"fixed","x":…,"y":…}`) instead of the
// synthesized `{"fixed":{"_0":[x,y]}}` shape, which would leak Swift's enum layout into the settings schema.
// A sequence is `{"kind":"sequence","points":[{"x":…,"y":…,"delayMilliseconds":…}, …]}`.
extension ClickTarget: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case x
        case y
        case points
    }

    private enum Kind: String, Codable {
        case currentCursor
        case fixed
        case sequence
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .currentCursor:
            self = .currentCursor
        case .fixed:
            let x = try container.decode(CGFloat.self, forKey: .x)
            let y = try container.decode(CGFloat.self, forKey: .y)
            self = .fixed(CGPoint(x: x, y: y))
        case .sequence:
            // Extra points cannot come from this build's editor; keeping the first ones beats discarding the settings.
            let points = try container.decode([ClickPoint].self, forKey: .points)
            self = .sequence(Array(points.prefix(Self.maxSequencePoints)))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .currentCursor:
            try container.encode(Kind.currentCursor, forKey: .kind)
        case .fixed(let point):
            try container.encode(Kind.fixed, forKey: .kind)
            try container.encode(point.x, forKey: .x)
            try container.encode(point.y, forKey: .y)
        case .sequence(let points):
            try container.encode(Kind.sequence, forKey: .kind)
            try container.encode(points, forKey: .points)
        }
    }
}
