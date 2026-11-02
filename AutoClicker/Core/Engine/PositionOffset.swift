import CoreGraphics

/// Draws the random position offset of one click: a vector uniformly distributed over a disk (ADR-012).
///
/// Uniform over the disk's area, not over its radius: the angle is uniform and the distance is `radius × √u` for a
/// uniform `u`. Drawing the distance uniformly instead would crowd the clicks around the center.
enum PositionOffset {
    /// Maps two unit samples to a point of the disk with radius `radius`.
    ///
    /// - Parameters:
    ///   - radius: The disk radius in points. Zero or less gives `.zero`.
    ///   - angleFraction: A sample in `0..<1`; the angle is `2π × angleFraction`.
    ///   - distanceFraction: A sample in `0...1`; the distance from the center is `radius × √distanceFraction`.
    static func vector(radius: Double, angleFraction: Double, distanceFraction: Double) -> CGVector {
        guard radius > 0 else {
            return .zero
        }
        let angle = 2 * Double.pi * angleFraction
        let distance = radius * min(max(distanceFraction, 0), 1).squareRoot()
        return CGVector(dx: distance * cos(angle), dy: distance * sin(angle))
    }

    /// Returns a random vector drawn uniformly from the disk with radius `radius`, in points.
    ///
    /// Pass a seeded generator in tests to make the sequence deterministic. A radius of zero or less returns `.zero`
    /// without consuming randomness.
    static func random(radius: Int, using generator: inout some RandomNumberGenerator) -> CGVector {
        guard radius > 0 else {
            return .zero
        }
        return vector(
            radius: Double(radius),
            angleFraction: Double.random(in: 0..<1, using: &generator),
            distanceFraction: Double.random(in: 0...1, using: &generator))
    }

    /// Returns a random vector drawn uniformly from the disk with radius `radius`, using the system random number
    /// generator.
    static func random(radius: Int) -> CGVector {
        var generator = SystemRandomNumberGenerator()
        return random(radius: radius, using: &generator)
    }
}
