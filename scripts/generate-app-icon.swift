// Generates the AutoClicker app icon and writes it into the asset catalog.
//
// Run from the repository root:
//
//     swift scripts/generate-app-icon.swift
//
// It renders every macOS AppIcon size (16-512 pt at 1x and 2x) into
// `AutoClicker/Assets.xcassets/AppIcon.appiconset`, rewrites its `Contents.json`, and writes a
// contact sheet to `build/icon-preview.png` (git-ignored) for judging the result by eye.
// Running it again overwrites the same files with the same output.
//
// Everything is drawn with Core Graphics paths. SF Symbols, system symbol images and emoji are
// deliberately not used: Apple's SF Symbols license forbids using them in app icons.
//
// This file lives outside `AutoClicker/` because every file in the app folders is copied into
// the app bundle.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Geometry

/// The design canvas. All coordinates below are in this space, with a top-left origin.
let canvasSize: CGFloat = 1024

/// The macOS icon grid: an 824 pt tile centered on the 1024 pt canvas.
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileCornerRadius: CGFloat = 185

/// The pointer: a tailless arrowhead with a notched base, in pointer units. The tip is at the
/// origin and the pointer's axis runs along +x; one unit is `RenderStyle.pointerLength`.
/// Each corner has its own rounding radius, also in pointer units.
let pointerCorners: [(point: CGPoint, radius: CGFloat)] = [
    (CGPoint(x: 0, y: 0), 0.07),  // tip
    (CGPoint(x: 1, y: 0.54), 0.13),  // wing
    (CGPoint(x: 0.76, y: 0), 0.12),  // notch
    (CGPoint(x: 1, y: -0.54), 0.13),  // wing
]

/// Tilt of the pointer, in degrees, measured from the upright pose in which its left edge is
/// vertical (negative turns it counterclockwise on screen).
let pointerTiltDegrees: CGFloat = -13

/// Settings that change with the output size so the small renders stay legible.
///
/// The small sizes use a larger pointer, fewer and thicker rings, and tighter shadows, because a
/// pixel there covers 32-64 canvas points.
struct RenderStyle {
    /// Length of the pointer from tip to wing tips, in canvas points.
    var pointerLength: CGFloat
    /// Radius of the soft "press" dot under the tip, in canvas points.
    var pressDotRadius: CGFloat
    /// Opacity of the press dot at its center.
    var pressDotAlpha: CGFloat
    /// Radii of the click rings, in canvas points.
    var ringRadii: [CGFloat]
    /// Opacity of each ring.
    var ringAlphas: [CGFloat]
    /// Stroke width of each ring, in canvas points.
    var ringWidths: [CGFloat]
    /// Downward offset of the pointer shadow, in canvas points.
    var shadowOffset: CGFloat
    /// Blur of the pointer shadow, in canvas points.
    var shadowBlur: CGFloat
    /// Opacity of the pointer shadow.
    var shadowAlpha: CGFloat
    /// Whether to draw the soft highlights and shading that only read at large sizes.
    var detailed: Bool

    init(pixelSize: Int) {
        switch pixelSize {
        case ...16:
            pointerLength = 500
            pressDotRadius = 0
            pressDotAlpha = 0
            ringRadii = [190]
            ringAlphas = [0.5]
            ringWidths = [64]
            shadowOffset = 24
            shadowBlur = 24
            shadowAlpha = 0.45
            detailed = false
        case ...32:
            pointerLength = 490
            pressDotRadius = 110
            pressDotAlpha = 0.3
            ringRadii = [195]
            ringAlphas = [0.6]
            ringWidths = [44]
            shadowOffset = 20
            shadowBlur = 28
            shadowAlpha = 0.4
            detailed = false
        case ...64:
            pointerLength = 475
            pressDotRadius = 100
            pressDotAlpha = 0.34
            ringRadii = [170, 250]
            ringAlphas = [0.62, 0.3]
            ringWidths = [30, 24]
            shadowOffset = 20
            shadowBlur = 40
            shadowAlpha = 0.38
            detailed = true
        default:
            pointerLength = 470
            pressDotRadius = 96
            pressDotAlpha = 0.34
            ringRadii = [165, 245]
            ringAlphas = [0.6, 0.28]
            ringWidths = [22, 16]
            shadowOffset = 22
            shadowBlur = 48
            shadowAlpha = 0.36
            detailed = true
        }
    }
}

// MARK: - Colors

func srgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let gradientTop = srgb(0x4F8B_FF)
let gradientBottom = srgb(0x1F4F_D8)
let shadowColor = srgb(0x0A20_6E)

// MARK: - Paths

/// A rounded rectangle with Apple-style continuous ("squircle") corners.
///
/// The control points are the widely used approximation of the curve behind
/// `UIBezierPath(roundedRect:cornerRadius:)` since iOS 7; each corner spans 1.528665 radii.
func continuousRoundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    let radius = min(radius, min(rect.width, rect.height) / 2 / 1.528_665)
    let path = CGMutablePath()
    // Each corner: its point, the unit vector back along the incoming edge, and the unit vector along
    // the outgoing edge. The path runs clockwise on screen.
    let corners: [(CGPoint, CGVector, CGVector)] = [
        (CGPoint(x: rect.maxX, y: rect.minY), CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: 1)),
        (CGPoint(x: rect.maxX, y: rect.maxY), CGVector(dx: 0, dy: -1), CGVector(dx: -1, dy: 0)),
        (CGPoint(x: rect.minX, y: rect.maxY), CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: -1)),
        (CGPoint(x: rect.minX, y: rect.minY), CGVector(dx: 0, dy: 1), CGVector(dx: 1, dy: 0)),
    ]
    for (index, (corner, incoming, outgoing)) in corners.enumerated() {
        func point(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(
                x: corner.x + radius * (along * incoming.dx + across * outgoing.dx),
                y: corner.y + radius * (along * incoming.dy + across * outgoing.dy)
            )
        }
        if index == 0 {
            path.move(to: point(1.528_665, 0))
        } else {
            path.addLine(to: point(1.528_665, 0))
        }
        path.addCurve(to: point(0.669_934, 0.065_496), control1: point(1.088_493, 0), control2: point(0.868_407, 0))
        path.addLine(to: point(0.631_494, 0.074_911))
        path.addCurve(
            to: point(0.074_912, 0.631_494),
            control1: point(0.372_824, 0.169_059),
            control2: point(0.169_060, 0.372_824)
        )
        path.addCurve(to: point(0, 1.528_665), control1: point(0, 0.868_407), control2: point(0, 1.088_493))
    }
    path.closeSubpath()
    return path
}

/// A closed polygon whose corners are rounded with circular arcs of the given radii.
func roundedPolygon(_ corners: [(point: CGPoint, radius: CGFloat)], transform: CGAffineTransform) -> CGPath {
    let path = CGMutablePath()
    let last = corners[corners.count - 1].point
    let first = corners[0].point
    path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2), transform: transform)
    for (index, corner) in corners.enumerated() {
        let next = corners[(index + 1) % corners.count].point
        path.addArc(tangent1End: corner.point, tangent2End: next, radius: corner.radius, transform: transform)
    }
    path.closeSubpath()
    return path
}

/// The foreground: the pointer, the press dot and the click rings, laid out for one render size.
struct Glyph {
    var pointer: CGPath
    /// The point the pointer's tip touches; the dot and rings are centered on it.
    var tip: CGPoint

    /// Builds the pointer around its tip, then moves the whole group so its visual bounds (ring
    /// strokes included) are centered on the tile.
    init(style: RenderStyle) {
        // Upright pose: the edge from the tip to the first wing points straight down.
        let wing = pointerCorners[1].point
        let upright = CGFloat.pi / 2 - atan2(wing.y, wing.x)
        let angle = upright + pointerTiltDegrees * .pi / 180
        let transform = CGAffineTransform(rotationAngle: angle).scaledBy(x: style.pointerLength, y: style.pointerLength)
        let pointer = roundedPolygon(pointerCorners, transform: transform)

        var bounds = pointer.boundingBoxOfPath
        let reach = max(style.pressDotRadius, (style.ringRadii.last ?? 0) + (style.ringWidths.last ?? 0) / 2)
        bounds = bounds.union(CGRect(x: -reach, y: -reach, width: reach * 2, height: reach * 2))
        var shift = CGAffineTransform(translationX: tileRect.midX - bounds.midX, y: tileRect.midY - bounds.midY)
        self.pointer = pointer.copy(using: &shift)!
        self.tip = CGPoint.zero.applying(shift)
    }
}

// MARK: - Drawing

/// Draws the icon into `context`, whose user space must already map the 1024 pt canvas
/// (top-left origin) onto the output. `pixelScale` is output pixels per canvas point.
func drawIcon(in context: CGContext, pixelScale: CGFloat, style: RenderStyle) {
    let tile = continuousRoundedRect(tileRect, radius: tileCornerRadius)

    // Drop shadow under the tile. Shadow offsets are in device space, where y grows upward.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -10 * pixelScale),
        blur: 20 * pixelScale,
        color: srgb(0x000000, alpha: style.detailed ? 0.32 : 0.2)
    )
    context.addPath(tile)
    context.setFillColor(gradientBottom)
    context.fillPath()
    context.restoreGState()

    // Tile background: vertical blue gradient.
    context.saveGState()
    context.addPath(tile)
    context.clip()
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [gradientTop, gradientBottom] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 0, y: tileRect.minY),
        end: CGPoint(x: 0, y: tileRect.maxY),
        options: []
    )

    // Soft highlight across the top of the tile.
    let highlight = CGGradient(
        colorsSpace: colorSpace,
        colors: [srgb(0xFFFFFF, alpha: 0.28), srgb(0xFFFFFF, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    context.saveGState()
    context.translateBy(x: canvasSize / 2, y: tileRect.minY)
    context.scaleBy(x: 1.6, y: 1)
    context.drawRadialGradient(
        highlight,
        startCenter: .zero,
        startRadius: 0,
        endCenter: .zero,
        endRadius: 470,
        options: []
    )
    context.restoreGState()

    if style.detailed {
        // A faint darker band at the bottom edge for depth.
        let shade = CGGradient(
            colorsSpace: colorSpace,
            colors: [srgb(0x0A1E66, alpha: 0), srgb(0x0A1E66, alpha: 0.22)] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            shade,
            start: CGPoint(x: 0, y: tileRect.maxY - 220),
            end: CGPoint(x: 0, y: tileRect.maxY),
            options: []
        )
    }
    context.restoreGState()

    let glyph = Glyph(style: style)
    drawRipples(around: glyph.tip, in: context, style: style)
    drawPointer(glyph.pointer, in: context, pixelScale: pixelScale, style: style)

    if style.detailed {
        // Thin inner stroke that catches the light along the tile's edge.
        context.saveGState()
        context.addPath(tile)
        context.clip()
        context.addPath(tile)
        context.setLineWidth(6)
        context.setStrokeColor(srgb(0xFFFFFF, alpha: 0.14))
        context.strokePath()
        context.restoreGState()
    }
}

/// A soft press dot and full concentric rings centered on the pointer's tip, partly behind it.
func drawRipples(around tip: CGPoint, in context: CGContext, style: RenderStyle) {
    if style.pressDotRadius > 0 {
        let dot = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                srgb(0xFFFFFF, alpha: style.pressDotAlpha),
                srgb(0xFFFFFF, alpha: style.pressDotAlpha * 0.7),
                srgb(0xFFFFFF, alpha: 0),
            ] as CFArray,
            locations: [0, 0.75, 1]
        )!
        context.drawRadialGradient(
            dot,
            startCenter: tip,
            startRadius: 0,
            endCenter: tip,
            endRadius: style.pressDotRadius,
            options: []
        )
    }
    context.saveGState()
    for (index, radius) in style.ringRadii.enumerated() {
        context.addEllipse(in: CGRect(x: tip.x - radius, y: tip.y - radius, width: radius * 2, height: radius * 2))
        context.setLineWidth(style.ringWidths[index])
        context.setStrokeColor(srgb(0xFFFFFF, alpha: style.ringAlphas[index]))
        context.strokePath()
    }
    context.restoreGState()
}

/// The white pointer with a soft, blue-tinted drop shadow.
func drawPointer(_ pointer: CGPath, in context: CGContext, pixelScale: CGFloat, style: RenderStyle) {
    // Shadow pass. Shadow offsets are in device space, where y grows upward.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -style.shadowOffset * pixelScale),
        blur: style.shadowBlur * pixelScale,
        color: shadowColor.copy(alpha: style.shadowAlpha)!
    )
    context.addPath(pointer)
    context.setFillColor(srgb(0xFFFFFF))
    context.fillPath()
    context.restoreGState()

    // Body: clean white with a very subtle top-to-bottom gradient.
    context.saveGState()
    context.addPath(pointer)
    context.clip()
    let body = CGGradient(
        colorsSpace: colorSpace,
        colors: [srgb(0xFFFFFF), srgb(style.detailed ? 0xE8EE_FA : 0xF4F7_FD)] as CFArray,
        locations: [0, 1]
    )!
    let bounds = pointer.boundingBox
    context.drawLinearGradient(
        body,
        start: CGPoint(x: bounds.midX, y: bounds.minY),
        end: CGPoint(x: bounds.midX, y: bounds.maxY),
        options: []
    )
    context.restoreGState()
}

// MARK: - Output

/// Renders the icon at `pixelSize` x `pixelSize` pixels.
func renderIcon(pixelSize: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let pixelScale = CGFloat(pixelSize) / canvasSize
    context.interpolationQuality = .high
    context.setShouldAntialias(true)
    // Flip to a top-left origin and map the 1024 pt canvas onto the output.
    context.translateBy(x: 0, y: CGFloat(pixelSize))
    context.scaleBy(x: pixelScale, y: -pixelScale)
    drawIcon(in: context, pixelScale: pixelScale, style: RenderStyle(pixelSize: pixelSize))
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        fatalError("Cannot create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Cannot write \(url.path)")
    }
}

/// A contact sheet: the 1024 render (shown at half size) next to the 128, 32 and 16 renders at
/// their real pixel size, plus 32 and 16 enlarged 8x without smoothing, on light and dark.
func renderPreview(icons: [Int: CGImage]) -> CGImage {
    let margin = 40
    let rowHeight = 512 + 2 * margin
    let width = margin + 512 + margin + 128 + margin + 32 + margin + 16 + margin + 256 + margin + 128 + margin
    let height = rowHeight * 2
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let backgrounds = [srgb(0xF5F5F7), srgb(0x1E1E20)]
    for (row, background) in backgrounds.enumerated() {
        // CG origin is bottom-left: row 0 (light) is drawn on top.
        let rowY = height - (row + 1) * rowHeight
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: rowY, width: width, height: rowHeight))
        let centerY = rowY + rowHeight / 2
        var x = margin
        func place(_ image: CGImage, size: Int, smooth: Bool) {
            context.interpolationQuality = smooth ? .high : .none
            context.draw(image, in: CGRect(x: x, y: centerY - size / 2, width: size, height: size))
            x += size + margin
        }
        place(icons[1024]!, size: 512, smooth: true)
        place(icons[128]!, size: 128, smooth: true)
        place(icons[32]!, size: 32, smooth: true)
        place(icons[16]!, size: 16, smooth: true)
        place(icons[32]!, size: 256, smooth: false)
        place(icons[16]!, size: 128, smooth: false)
    }
    return context.makeImage()!
}

func contentsJSON(entries: [(points: Int, scale: Int)]) -> String {
    let images = entries.map { entry in
        """
            {
              "filename" : "\(fileName(points: entry.points, scale: entry.scale))",
              "idiom" : "mac",
              "scale" : "\(entry.scale)x",
              "size" : "\(entry.points)x\(entry.points)"
            }
        """
    }
    return """
        {
          "images" : [
        \(images.joined(separator: ",\n"))
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }

        """
}

func fileName(points: Int, scale: Int) -> String {
    scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@\(scale)x.png"
}

// MARK: - Main

let repositoryRoot = URL(fileURLWithPath: #filePath).standardizedFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let iconSet = repositoryRoot.appendingPathComponent("AutoClicker/Assets.xcassets/AppIcon.appiconset")
let buildFolder = repositoryRoot.appendingPathComponent("build")

let entries: [(points: Int, scale: Int)] = [16, 32, 128, 256, 512].flatMap { [($0, 1), ($0, 2)] }
var renders: [Int: CGImage] = [:]
for entry in entries {
    let pixels = entry.points * entry.scale
    let image = renders[pixels] ?? renderIcon(pixelSize: pixels)
    renders[pixels] = image
    let url = iconSet.appendingPathComponent(fileName(points: entry.points, scale: entry.scale))
    writePNG(image, to: url)
    print("Wrote \(url.lastPathComponent) (\(pixels) px)")
}

try contentsJSON(entries: entries)
    .write(to: iconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Wrote Contents.json")

try FileManager.default.createDirectory(at: buildFolder, withIntermediateDirectories: true)
let previewURL = buildFolder.appendingPathComponent("icon-preview.png")
writePNG(renderPreview(icons: renders), to: previewURL)
print("Wrote \(previewURL.path)")
