import CoreGraphics
import Testing

@testable import AutoClicker

struct ScreenGeometryTests {
    // MARK: - Fixtures (AppKit frames, primary first)

    /// 1440x900 primary only.
    private static let singleScreen = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

    /// 1440x900 primary with a 1920x1080 secondary to its right, bottom edges aligned in AppKit.
    private static let sideBySide = [
        CGRect(x: 0, y: 0, width: 1440, height: 900),
        CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    ]

    /// 1440x900 primary with a 1920x1080 secondary above it, horizontally offset to the left.
    private static let secondaryAbove = [
        CGRect(x: 0, y: 0, width: 1440, height: 900),
        CGRect(x: -240, y: 900, width: 1920, height: 1080),
    ]

    /// 1440x900 primary with a 1280x800 secondary below it.
    private static let secondaryBelow = [
        CGRect(x: 0, y: 0, width: 1440, height: 900),
        CGRect(x: 80, y: -800, width: 1280, height: 800),
    ]

    /// 1440x900 primary with a 2560x1440 secondary to its left, top edges aligned in AppKit.
    private static let secondaryLeft = [
        CGRect(x: 0, y: 0, width: 1440, height: 900),
        CGRect(x: -2560, y: -540, width: 2560, height: 1440),
    ]

    // MARK: - Single screen

    @Test func singleScreenConvertsPoints() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.singleScreen)
        #expect(geometry.cgPoint(fromAppKit: CGPoint(x: 0, y: 0)) == CGPoint(x: 0, y: 900))
        #expect(geometry.cgPoint(fromAppKit: CGPoint(x: 0, y: 900)) == CGPoint(x: 0, y: 0))
        #expect(geometry.cgPoint(fromAppKit: CGPoint(x: 100, y: 200)) == CGPoint(x: 100, y: 700))
        #expect(geometry.appKitPoint(fromCG: CGPoint(x: 100, y: 700)) == CGPoint(x: 100, y: 200))
    }

    @Test func singleScreenFrameInCGSpace() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.singleScreen)
        #expect(geometry.cgScreenFrames == [CGRect(x: 0, y: 0, width: 1440, height: 900)])
    }

    @Test func singleScreenHasFourCorners() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.singleScreen)
        #expect(
            Set(geometry.cgCorners.map(PointKey.init)) == [
                PointKey(CGPoint(x: 0, y: 0)),
                PointKey(CGPoint(x: 1440, y: 0)),
                PointKey(CGPoint(x: 0, y: 900)),
                PointKey(CGPoint(x: 1440, y: 900)),
            ])
    }

    // MARK: - Multiple screens

    @Test func sideBySideSecondaryHasTopAlignedToPrimaryHeight() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.sideBySide)
        // The taller secondary extends 180 pt above the primary's top edge, so its CG minY is negative.
        #expect(geometry.cgScreenFrames[1] == CGRect(x: 1440, y: -180, width: 1920, height: 1080))
        #expect(geometry.cgCorners.count == 8)
    }

    @Test func secondaryAboveHasNegativeCGCoordinates() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.secondaryAbove)
        #expect(geometry.cgScreenFrames[1] == CGRect(x: -240, y: -1080, width: 1920, height: 1080))
        #expect(geometry.cgPoint(fromAppKit: CGPoint(x: -240, y: 1980)) == CGPoint(x: -240, y: -1080))
    }

    @Test func secondaryBelowLiesBeyondPrimaryHeight() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.secondaryBelow)
        #expect(geometry.cgScreenFrames[1] == CGRect(x: 80, y: 900, width: 1280, height: 800))
        #expect(geometry.cgPoint(fromAppKit: CGPoint(x: 80, y: -800)) == CGPoint(x: 80, y: 1700))
    }

    @Test func secondaryLeftHasNegativeX() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.secondaryLeft)
        #expect(geometry.cgScreenFrames[1] == CGRect(x: -2560, y: 0, width: 2560, height: 1440))
    }

    @Test func mixedHeightsUseOnlyThePrimaryHeight() {
        // A tall primary and a short secondary: the secondary's height must not affect the conversion.
        let frames = [
            CGRect(x: 0, y: 0, width: 1920, height: 1200),
            CGRect(x: 1920, y: 400, width: 1024, height: 768),
        ]
        let geometry = ScreenGeometry(appKitScreenFrames: frames)
        #expect(geometry.cgScreenFrames[1] == CGRect(x: 1920, y: 32, width: 1024, height: 768))
        #expect(geometry.cgPoint(fromAppKit: CGPoint(x: 2000, y: 500)) == CGPoint(x: 2000, y: 700))
    }

    @Test func emptyScreenListHasNoCornersAndNoContainingFrame() {
        let geometry = ScreenGeometry(appKitScreenFrames: [])
        #expect(geometry.cgCorners.isEmpty)
        #expect(geometry.screenFrameContaining(.zero) == nil)
        #expect(!geometry.isNearCorner(.zero))
    }

    // MARK: - Round trips

    @Test(arguments: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 720.5, y: 450.25),
        CGPoint(x: -2000, y: 1300),
        CGPoint(x: 3000, y: -700),
    ])
    func pointRoundTrips(point: CGPoint) {
        for frames in [Self.singleScreen, Self.sideBySide, Self.secondaryAbove, Self.secondaryLeft] {
            let geometry = ScreenGeometry(appKitScreenFrames: frames)
            #expect(geometry.appKitPoint(fromCG: geometry.cgPoint(fromAppKit: point)) == point)
            #expect(geometry.cgPoint(fromAppKit: geometry.appKitPoint(fromCG: point)) == point)
        }
    }

    @Test func rectRoundTrips() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.secondaryAbove)
        let rect = CGRect(x: -100, y: 950, width: 300, height: 200)
        let cgRect = geometry.cgRect(fromAppKit: rect)
        #expect(cgRect == CGRect(x: -100, y: -250, width: 300, height: 200))
        #expect(geometry.appKitRect(fromCG: cgRect) == rect)
    }

    // MARK: - Containing screen

    @Test func screenFrameContainingFindsTheRightScreen() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.secondaryAbove)
        #expect(geometry.screenFrameContaining(CGPoint(x: 10, y: 10)) == geometry.cgScreenFrames[0])
        #expect(geometry.screenFrameContaining(CGPoint(x: -200, y: -10)) == geometry.cgScreenFrames[1])
        #expect(geometry.screenFrameContaining(CGPoint(x: -200, y: 10)) == nil)
    }

    // MARK: - Corner detection

    @Test(arguments: [(0, true), (2, true), (3, false)] as [(CGFloat, Bool)])
    func primaryCornersRespectTolerance(offset: CGFloat, expected: Bool) {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.sideBySide)
        // Offsets move inward from each primary corner along both axes.
        #expect(geometry.isNearCorner(CGPoint(x: 0 + offset, y: 0 + offset)) == expected)
        #expect(geometry.isNearCorner(CGPoint(x: 0 + offset, y: 900 - offset)) == expected)
        #expect(geometry.isNearCorner(CGPoint(x: 1440 - offset, y: 0 + offset)) == expected)
        #expect(geometry.isNearCorner(CGPoint(x: 1440 - offset, y: 900 - offset)) == expected)
    }

    @Test(arguments: [(0, true), (2, true), (3, false)] as [(CGFloat, Bool)])
    func secondaryCornersRespectTolerance(offset: CGFloat, expected: Bool) {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.secondaryAbove)
        // Secondary in CG space: x -240...1680, y -1080...0.
        #expect(geometry.isNearCorner(CGPoint(x: -240 + offset, y: -1080 + offset)) == expected)
        #expect(geometry.isNearCorner(CGPoint(x: 1680 - offset, y: -1080 + offset)) == expected)
        #expect(geometry.isNearCorner(CGPoint(x: -240 + offset, y: 0 - offset)) == expected)
        #expect(geometry.isNearCorner(CGPoint(x: 1680 - offset, y: 0 - offset)) == expected)
    }

    @Test func cornerCheckIsPerAxis() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.singleScreen)
        // Within tolerance on one axis only is not a corner hit.
        #expect(!geometry.isNearCorner(CGPoint(x: 1, y: 3)))
        #expect(!geometry.isNearCorner(CGPoint(x: 3, y: 1)))
        #expect(geometry.isNearCorner(CGPoint(x: 1.5, y: 2)))
    }

    @Test func cornerCheckHonoursCustomTolerance() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.singleScreen)
        #expect(geometry.isNearCorner(CGPoint(x: 5, y: 5), tolerance: 5))
        #expect(!geometry.isNearCorner(CGPoint(x: 1, y: 1), tolerance: 0))
        #expect(geometry.isNearCorner(CGPoint(x: 0, y: 0), tolerance: 0))
    }

    @Test func centerOfScreenIsNotNearCorner() {
        let geometry = ScreenGeometry(appKitScreenFrames: Self.sideBySide)
        #expect(!geometry.isNearCorner(CGPoint(x: 720, y: 450)))
        #expect(!geometry.isNearCorner(CGPoint(x: 2400, y: 360)))
    }
}

/// `CGPoint` is not `Hashable`, so tests wrap it to compare corner lists as sets.
private struct PointKey: Hashable {
    let x: CGFloat
    let y: CGFloat

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }
}
