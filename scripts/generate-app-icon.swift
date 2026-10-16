// Generates the AutoClicker app icon as an Icon Composer document.
//
// Run from the repository root:
//
//     swift scripts/generate-app-icon.swift
//
// It writes `AutoClicker/AppIcon.icon` (an `icon.json` plus one SVG per foreground layer) and,
// when Xcode's `ictool` is available, renders the light, dark and tinted appearances into a
// contact sheet at `build/icon-preview.png` (git-ignored) for judging the result by eye.
// Running it again overwrites the same files with the same output.
//
// The document holds only flat, white foreground shapes and the background fill. The system adds
// the squircle mask, Liquid Glass, specular highlights and shadows, and derives the tinted
// appearance. When the app is built, actool compiles the document into `Assets.car`, including
// flattened fallbacks for macOS 14 and 15.
//
// Every shape is drawn with Core Graphics paths and exported as SVG path data. SF Symbols, system
// symbol images and emoji are deliberately not used: Apple's SF Symbols license forbids using
// them in app icons.
//
// This file lives outside `AutoClicker/` because every file in the app folders is copied into
// the app bundle.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Geometry

/// The icon canvas, in points with a top-left origin. In Icon Composer the canvas is the whole
/// tile; the system applies the squircle mask and the margins of each platform's grid.
let canvasSize: CGFloat = 1024

/// The pointer: a tailless arrowhead with a notched base, in pointer units. The tip is at the
/// origin and the pointer's axis runs along +x; one unit is `pointerLength`.
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

/// Length of the pointer from tip to wing tips, in canvas points.
let pointerLength: CGFloat = 520

/// Radius of the "press" dot under the tip, in canvas points.
let pressDotRadius: CGFloat = 100

/// The click rings around the tip: radius and stroke width, in canvas points. An Icon Composer
/// document has no per-size artwork, so the strokes are bold enough to survive at 16 px.
let ringSpecs: [(radius: CGFloat, width: CGFloat)] = [
    (182, 36),
    (270, 28),
]

// MARK: - Colors

/// An Icon Composer color string.
func iconColor(_ hex: UInt32, alpha: CGFloat = 1) -> String {
    let components = [(hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF].map { CGFloat($0) / 255 }
    return "srgb:" + (components + [alpha]).map { String(format: "%.5f", $0) }.joined(separator: ",")
}

func srgb(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

/// Background gradients, top to bottom.
let lightBackground: [UInt32] = [0x4F8B_FF, 0x1F4F_D8]
let darkBackground: [UInt32] = [0x1E25_33, 0x0D10_18]

/// In dark mode the rings and the press dot take the accent blue so they glow on the graphite tile.
let darkAccent: UInt32 = 0x4C84_FF

// MARK: - Shapes

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

/// The foreground shapes, laid out on the canvas. The pointer's tip sits at the center of the
/// press dot and rings, and the whole group is centered on the canvas.
struct Glyph {
    var pointer: CGPath
    var pressDot: CGPath
    /// Each ring as a filled outline, innermost first.
    var rings: [CGPath]

    init() {
        // Upright pose: the edge from the tip to the first wing points straight down.
        let wing = pointerCorners[1].point
        let upright = CGFloat.pi / 2 - atan2(wing.y, wing.x)
        let angle = upright + pointerTiltDegrees * .pi / 180
        let transform = CGAffineTransform(rotationAngle: angle).scaledBy(x: pointerLength, y: pointerLength)
        let pointer = roundedPolygon(pointerCorners, transform: transform)

        let outer = ringSpecs.map { $0.radius + $0.width / 2 }.max() ?? 0
        let reach = max(pressDotRadius, outer)
        let bounds = pointer.boundingBoxOfPath.union(CGRect(x: -reach, y: -reach, width: reach * 2, height: reach * 2))
        var shift = CGAffineTransform(translationX: canvasSize / 2 - bounds.midX, y: canvasSize / 2 - bounds.midY)
        let tip = CGPoint.zero.applying(shift)

        func circle(radius: CGFloat) -> CGPath {
            CGPath(
                ellipseIn: CGRect(x: tip.x - radius, y: tip.y - radius, width: radius * 2, height: radius * 2),
                transform: nil)
        }
        self.pointer = pointer.copy(using: &shift)!
        self.pressDot = circle(radius: pressDotRadius)
        self.rings = ringSpecs.map { ring in
            circle(radius: ring.radius).copy(
                strokingWithWidth: ring.width, lineCap: .butt, lineJoin: .miter, miterLimit: 10)
        }
    }
}

// MARK: - SVG

/// SVG path data for `path`, with coordinates rounded to 1/100 pt.
func svgPathData(_ path: CGPath) -> String {
    var commands: [String] = []
    func format(_ points: UnsafeMutablePointer<CGPoint>, _ count: Int) -> String {
        (0..<count).map { String(format: "%.2f %.2f", points[$0].x, points[$0].y) }.joined(separator: " ")
    }
    path.applyWithBlock { element in
        let points = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint:
            commands.append("M" + format(points, 1))
        case .addLineToPoint:
            commands.append("L" + format(points, 1))
        case .addQuadCurveToPoint:
            commands.append("Q" + format(points, 2))
        case .addCurveToPoint:
            commands.append("C" + format(points, 3))
        case .closeSubpath:
            commands.append("Z")
        @unknown default:
            fatalError("Unknown path element")
        }
    }
    return commands.joined(separator: " ")
}

/// A 1024 x 1024 SVG with one white shape on a transparent background.
func svgDocument(_ path: CGPath) -> String {
    let size = Int(canvasSize)
    return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(size)" height="\(size)" viewBox="0 0 \(size) \(size)">
          <path fill="#FFFFFF" fill-rule="nonzero" d="\(svgPathData(path))"/>
        </svg>

        """
}

// MARK: - Icon document

/// A layer of the icon: its SVG file name, its opacity in light mode, and its dark-mode
/// color and opacity (nil keeps the light-mode white).
struct Layer {
    var name: String
    var path: CGPath
    var opacity: CGFloat
    var darkColor: UInt32?
    var darkOpacity: CGFloat

    var fileName: String { "\(name).svg" }

    var json: [String: Any] {
        var json: [String: Any] = [
            "image-name": fileName,
            "name": name,
            "glass": true,
        ]
        if opacity < 1 || darkOpacity < 1 {
            json["opacity-specializations"] = [
                ["value": opacity],
                ["appearance": "dark", "value": darkOpacity],
            ]
        }
        if let darkColor {
            json["fill-specializations"] = [
                ["appearance": "dark", "value": ["solid": iconColor(darkColor)]]
            ]
        }
        return json
    }
}

func linearGradient(_ colors: [UInt32]) -> [String: Any] {
    [
        "linear-gradient": colors.map { iconColor($0) },
        "orientation": [
            "start": ["x": 0.5, "y": 0],
            "stop": ["x": 0.5, "y": 1],
        ],
    ]
}

/// The `icon.json` content: the pointer group in front of the ripple group, over the fill.
/// Groups and layers are listed front to back.
func iconDocument(pointer: [Layer], ripples: [Layer]) -> [String: Any] {
    [
        "fill-specializations": [
            ["value": linearGradient(lightBackground)],
            ["appearance": "dark", "value": linearGradient(darkBackground)],
        ],
        "groups": [
            [
                "layers": pointer.map(\.json),
                "shadow": ["kind": "neutral", "opacity": 0.5],
                "translucency": ["enabled": false, "value": 0.5],
                "specular": true,
            ],
            [
                "layers": ripples.map(\.json),
                "shadow": ["kind": "neutral", "opacity": 0.25],
                "translucency": ["enabled": true, "value": 0.3],
                "specular": true,
            ],
        ],
        "supported-platforms": [
            "squares": ["macOS"]
        ],
    ]
}

// MARK: - Preview

/// Xcode's Icon Composer renderer, if this machine has it.
func ictoolURL() -> URL? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    process.standardOutput = pipe
    guard (try? process.run()) != nil else { return nil }
    process.waitUntilExit()
    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let developer = URL(fileURLWithPath: output.trimmingCharacters(in: .whitespacesAndNewlines))
    let url = developer.deletingLastPathComponent()
        .appendingPathComponent("Applications/Icon Composer.app/Contents/Executables/ictool")
    return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
}

/// Renders one appearance of the icon document at `size` pixels with `ictool`.
func render(_ icon: URL, ictool: URL, rendition: String, size: Int, into folder: URL) -> CGImage {
    let output = folder.appendingPathComponent("\(rendition)-\(size).png")
    let process = Process()
    process.executableURL = ictool
    process.arguments = [
        icon.path, "--export-image", "--output-file", output.path, "--platform", "macOS", "--rendition", rendition,
        "--width", "\(size)", "--height", "\(size)", "--scale", "1",
    ]
    do {
        try process.run()
    } catch {
        fatalError("Cannot run ictool: \(error)")
    }
    process.waitUntilExit()
    guard
        process.terminationStatus == 0,
        let source = CGImageSourceCreateWithURL(output as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        fatalError("ictool failed to render \(rendition) at \(size) px")
    }
    return image
}

/// A contact sheet with one row per appearance: the 1024 render (shown at half size), the 128, 32
/// and 16 renders at their real pixel size, and the 32 and 16 renders enlarged 8x without
/// smoothing.
func renderPreview(rows: [(background: CGColor, icons: [Int: CGImage])]) -> CGImage {
    let margin = 40
    let rowHeight = 512 + 2 * margin
    let width = margin + 512 + margin + 128 + margin + 32 + margin + 16 + margin + 256 + margin + 128 + margin
    let height = rowHeight * rows.count
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    for (index, row) in rows.enumerated() {
        // CG origin is bottom-left: the first row is drawn on top.
        let rowY = height - (index + 1) * rowHeight
        context.setFillColor(row.background)
        context.fill(CGRect(x: 0, y: rowY, width: width, height: rowHeight))
        let centerY = rowY + rowHeight / 2
        var x = margin
        func place(_ image: CGImage, size: Int, smooth: Bool) {
            context.interpolationQuality = smooth ? .high : .none
            context.draw(image, in: CGRect(x: x, y: centerY - size / 2, width: size, height: size))
            x += size + margin
        }
        place(row.icons[1024]!, size: 512, smooth: true)
        place(row.icons[128]!, size: 128, smooth: true)
        place(row.icons[32]!, size: 32, smooth: true)
        place(row.icons[16]!, size: 16, smooth: true)
        place(row.icons[32]!, size: 256, smooth: false)
        place(row.icons[16]!, size: 128, smooth: false)
    }
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

// MARK: - Main

let repositoryRoot = URL(fileURLWithPath: #filePath).standardizedFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let iconURL = repositoryRoot.appendingPathComponent("AutoClicker/AppIcon.icon")
let assetsURL = iconURL.appendingPathComponent("Assets")
let buildFolder = repositoryRoot.appendingPathComponent("build")
let fileManager = FileManager.default

let glyph = Glyph()
let pointerLayers = [
    Layer(name: "pointer", path: glyph.pointer, opacity: 1, darkColor: nil, darkOpacity: 1)
]
let rippleLayers = [
    Layer(name: "ring-inner", path: glyph.rings[0], opacity: 0.7, darkColor: darkAccent, darkOpacity: 0.95),
    Layer(name: "ring-outer", path: glyph.rings[1], opacity: 0.38, darkColor: darkAccent, darkOpacity: 0.55),
    Layer(name: "press-dot", path: glyph.pressDot, opacity: 0.32, darkColor: darkAccent, darkOpacity: 0.4),
]

// Start from a clean bundle so renamed layers leave no stale files behind.
try? fileManager.removeItem(at: iconURL)
try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
for layer in pointerLayers + rippleLayers {
    try svgDocument(layer.path)
        .write(to: assetsURL.appendingPathComponent(layer.fileName), atomically: true, encoding: .utf8)
    print("Wrote Assets/\(layer.fileName)")
}
let json = try JSONSerialization.data(
    withJSONObject: iconDocument(pointer: pointerLayers, ripples: rippleLayers),
    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
)
try (json + Data("\n".utf8)).write(to: iconURL.appendingPathComponent("icon.json"))
print("Wrote \(iconURL.path)")

if let ictool = ictoolURL() {
    let renders = buildFolder.appendingPathComponent("icon-renders")
    try fileManager.createDirectory(at: renders, withIntermediateDirectories: true)
    let appearances: [(rendition: String, background: CGColor)] = [
        ("Default", srgb(0xF5F5F7)),
        ("Dark", srgb(0x1E1E20)),
        ("TintedLight", srgb(0xF5F5F7)),
        ("TintedDark", srgb(0x1E1E20)),
    ]
    let rows = appearances.map { appearance in
        let icons = [1024, 128, 32, 16].map { size in
            (size, render(iconURL, ictool: ictool, rendition: appearance.rendition, size: size, into: renders))
        }
        return (background: appearance.background, icons: Dictionary(uniqueKeysWithValues: icons))
    }
    let previewURL = buildFolder.appendingPathComponent("icon-preview.png")
    writePNG(renderPreview(rows: rows), to: previewURL)
    print("Wrote \(previewURL.path)")
} else {
    print("Skipped the preview: Icon Composer's ictool was not found (needs Xcode 26 or later).")
}
