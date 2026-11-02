import CoreGraphics
import Foundation
import Testing

@testable import AutoClicker

struct PositionOffsetTests {
    private static func length(_ vector: CGVector) -> Double {
        hypot(vector.dx, vector.dy)
    }

    // MARK: - Disk mapping

    @Test func mapsTheUnitSamplesOntoTheDisk() {
        let tolerance = 1e-9
        let east = PositionOffset.vector(radius: 10, angleFraction: 0, distanceFraction: 1)
        #expect(abs(east.dx - 10) < tolerance && abs(east.dy) < tolerance)

        let south = PositionOffset.vector(radius: 10, angleFraction: 0.25, distanceFraction: 1)
        #expect(abs(south.dx) < tolerance && abs(south.dy - 10) < tolerance)

        let west = PositionOffset.vector(radius: 10, angleFraction: 0.5, distanceFraction: 1)
        #expect(abs(west.dx + 10) < tolerance && abs(west.dy) < tolerance)
    }

    @Test func distanceIsTheSquareRootOfTheSample() {
        // A quarter of the samples must land within half the radius, because that inner disk has a quarter of the area.
        let half = PositionOffset.vector(radius: 100, angleFraction: 0.1, distanceFraction: 0.25)
        #expect(abs(Self.length(half) - 50) < 1e-9)
        #expect(PositionOffset.vector(radius: 100, angleFraction: 0.3, distanceFraction: 0) == .zero)
    }

    @Test func outOfRangeDistanceSamplesAreClamped() {
        #expect(abs(Self.length(PositionOffset.vector(radius: 8, angleFraction: 0.7, distanceFraction: 4)) - 8) < 1e-9)
        #expect(Self.length(PositionOffset.vector(radius: 8, angleFraction: 0.7, distanceFraction: -1)) == 0)
    }

    @Test(arguments: [0.0, -3.0])
    func zeroOrNegativeRadiusGivesNoOffset(_ radius: Double) {
        #expect(PositionOffset.vector(radius: radius, angleFraction: 0.4, distanceFraction: 0.9) == .zero)
    }

    // MARK: - Random draws

    @Test(arguments: [0, -1])
    func zeroOrNegativeRadiusDrawsNothing(_ radius: Int) {
        var generator = CountingGenerator(SeededGenerator(seed: 3))
        #expect(PositionOffset.random(radius: radius, using: &generator) == .zero)
        #expect(generator.draws == 0)
        #expect(PositionOffset.random(radius: radius) == .zero)
    }

    @Test(arguments: [1, 7, 50, 200])
    func everySampleIsInsideTheDisk(_ radius: Int) {
        var generator = SeededGenerator(seed: UInt64(radius))
        for _ in 0..<5_000 {
            let vector = PositionOffset.random(radius: radius, using: &generator)
            #expect(Self.length(vector) <= Double(radius) + 1e-9)
        }
    }

    @Test func systemGeneratorSamplesStayInsideTheDisk() {
        for _ in 0..<1_000 {
            #expect(Self.length(PositionOffset.random(radius: 20)) <= 20 + 1e-9)
        }
    }

    @Test func seededDrawsAreReproducible() {
        var first = SeededGenerator(seed: 99)
        var second = SeededGenerator(seed: 99)
        let a = (0..<20).map { _ in PositionOffset.random(radius: 40, using: &first) }
        let b = (0..<20).map { _ in PositionOffset.random(radius: 40, using: &second) }
        #expect(a == b)
    }

    @Test func samplesAreSpreadUniformlyOverTheArea() {
        var generator = SeededGenerator(seed: 2026)
        let radius = 100.0
        let count = 40_000
        var innerHalfRadius = 0
        var innerHalfArea = 0
        var quadrants = [0, 0, 0, 0]
        var sum = CGVector.zero
        for _ in 0..<count {
            let vector = PositionOffset.random(radius: Int(radius), using: &generator)
            let distance = Self.length(vector)
            if distance <= radius / 2 {
                innerHalfRadius += 1
            }
            if distance <= radius / 2.squareRoot() {
                innerHalfArea += 1
            }
            quadrants[(vector.dx >= 0 ? 0 : 1) + (vector.dy >= 0 ? 0 : 2)] += 1
            sum.dx += vector.dx
            sum.dy += vector.dy
        }

        // Uniform over the area: the disk of half the radius holds 25 %, the one of radius/√2 holds 50 %.
        // Drawing the distance uniformly instead would put 50 % within half the radius.
        let tolerance = 0.015
        #expect(abs(Double(innerHalfRadius) / Double(count) - 0.25) < tolerance)
        #expect(abs(Double(innerHalfArea) / Double(count) - 0.5) < tolerance)
        for quadrant in quadrants {
            #expect(abs(Double(quadrant) / Double(count) - 0.25) < tolerance)
        }
        // No direction is favored: the mean vector stays near the center.
        #expect(abs(sum.dx / Double(count)) < 1.5)
        #expect(abs(sum.dy / Double(count)) < 1.5)
    }
}

/// Deterministic SplitMix64 generator so offset tests are reproducible.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Wraps a generator and counts how many values were drawn from it.
private struct CountingGenerator<Base: RandomNumberGenerator>: RandomNumberGenerator {
    private var base: Base
    private(set) var draws = 0

    init(_ base: Base) {
        self.base = base
    }

    mutating func next() -> UInt64 {
        draws += 1
        return base.next()
    }
}
