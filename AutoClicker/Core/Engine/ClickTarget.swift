import CoreGraphics

/// Where each click lands.
///
/// Points are in CG global space (top-left origin of the main display). Conversion from AppKit coordinates
/// happens only in `ScreenGeometry` (ADR-006).
enum ClickTarget: Sendable, Equatable {
    /// Click wherever the cursor is when the tick fires.
    case currentCursor
    /// Click at a fixed point in CG global space.
    case fixed(CGPoint)
}

// Custom coding keeps the persisted JSON flat and readable (`{"kind":"fixed","x":…,"y":…}`) instead of the
// synthesized `{"fixed":{"_0":[x,y]}}` shape, which would leak Swift's enum layout into the settings schema.
extension ClickTarget: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case x
        case y
    }

    private enum Kind: String, Codable {
        case currentCursor
        case fixed
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
        }
    }
}
