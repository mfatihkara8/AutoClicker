// A click target and verifier for scripts/live-check.sh. Not part of the app: the script compiles it into build/.
//
// Usage:
//
//     click-target record FRAME_FILE CLICKS_FILE SECONDS
//         Opens a floating 400x300 window at a fixed place on the main display, writes its frames (CG global,
//         top-left origin) to FRAME_FILE as JSON, appends one JSON line per mouse down it receives to CLICKS_FILE,
//         and quits after SECONDS or on SIGTERM/SIGINT. It puts the pointer back where it was when it quits. It only
//         receives events, so it needs no permission.
//
//     click-target verify CLICKS_FILE RESULT_FILE
//         Compares the recorded clicks with the app's live-check result and prints PASS/FAIL per check. Exits 1 when
//         any check fails.

import AppKit
import Foundation

// MARK: - Shared shapes

struct Rect: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = rect.minX
        y = rect.minY
        width = rect.width
        height = rect.height
    }
}

/// What FRAME_FILE holds. The app reads `content` to place its points.
struct TargetFrames: Codable {
    var window: Rect
    var content: Rect
    var pid: Int32
}

/// One recorded mouse down.
struct RecordedClick: Codable {
    var time: Double
    var type: String
    var button: Int
    var clickCount: Int
    var clickState: Int64
    var x: Double
    var y: Double
    var modifiers: [String]
}

/// The part of the app's result file (LiveCheckResult in the app) that the verifier reads.
struct AppResult: Decodable {
    struct Point: Decodable {
        var x: Double
        var y: Double
    }
    struct Run: Decodable {
        var started: Bool
        var points: [Point]
        var positionOffset: Int
        var modifiers: [String]
        var clickType: String
        var expectedClicks: Int
        var countedClicks: Int
        var stopReason: String?
    }
    struct AddedPoint: Decodable {
        var requested: Point
        var appended: Point?
        var delayMilliseconds: Int?
        var countdownSeconds: Double
        var distance: Double?
        var passed: Bool
    }
    struct AddPoint: Decodable {
        var method: String
        var points: [AddedPoint]
        var passed: Bool
    }
    struct MenuItem: Decodable {
        var title: String
        var isChecked: Bool
        var isEnabled: Bool
    }
    struct Profiles: Decodable {
        var method: String
        var itemsBefore: [MenuItem]
        var itemsAfter: [MenuItem]
        var activeBefore: String?
        var chosen: String
        var activeAfter: String?
        var configurationMatchesChosen: Bool
        var passed: Bool
    }
    var accessibilityTrusted: Bool
    var addPoint: AddPoint
    var profiles: Profiles?
    var run: Run?
    var notes: [String]
}

func describe(_ items: [AppResult.MenuItem]) -> String {
    items.map { "\($0.isChecked ? "✓ " : "")\($0.title)\($0.isEnabled ? "" : " (disabled)")" }.joined(separator: ", ")
}

// MARK: - Recording

/// Converts AppKit global coordinates (bottom-left origin of the main display) to CG global (top-left origin).
@MainActor
func cgRect(fromAppKit rect: CGRect) -> CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
}

func modifierNames(_ flags: NSEvent.ModifierFlags) -> [String] {
    var names: [String] = []
    if flags.contains(.control) { names.append("control") }
    if flags.contains(.option) { names.append("option") }
    if flags.contains(.shift) { names.append("shift") }
    if flags.contains(.command) { names.append("command") }
    return names
}

/// Draws a dot at every recorded click, so the person watching sees where the clicks landed.
final class TargetView: NSView {
    var dots: [CGPoint] = []

    override var isFlipped: Bool { true }

    // A click on a window of an inactive app still reaches the view.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        let text = "AutoClicker live check target: \(dots.count) clicks" as NSString
        text.draw(
            at: CGPoint(x: 12, y: 10),
            withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor])
        NSColor.systemRed.setFill()
        for dot in dots {
            NSBezierPath(ovalIn: CGRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6)).fill()
        }
    }
}

/// Records every mouse down in `sendEvent`, before AppKit decides whether a view gets it.
final class TargetWindow: NSWindow {
    var log: FileHandle?
    var onClick: ((CGPoint) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        let typeName: String? =
            switch event.type {
            case .leftMouseDown: "leftMouseDown"
            case .rightMouseDown: "rightMouseDown"
            case .otherMouseDown: "otherMouseDown"
            default: nil
            }
        if let typeName {
            // The CGEvent location is already CG global; the window conversion is the fallback.
            let location =
                event.cgEvent?.location
                ?? cgRect(fromAppKit: CGRect(origin: convertPoint(toScreen: event.locationInWindow), size: .zero))
                .origin
            let click = RecordedClick(
                time: Date().timeIntervalSince1970,
                type: typeName,
                button: event.buttonNumber,
                clickCount: event.clickCount,
                clickState: event.cgEvent?.getIntegerValueField(.mouseEventClickState) ?? -1,
                x: location.x,
                y: location.y,
                modifiers: modifierNames(event.modifierFlags))
            if var line = try? JSONEncoder().encode(click) {
                line.append(0x0A)
                // Written right away, so a kill loses nothing.
                log?.write(line)
            }
            onClick?(convertPoint(toScreen: event.locationInWindow))
        }
        super.sendEvent(event)
    }
}

@MainActor
func record(frameFile: String, clicksFile: String, seconds: Double) -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    // CG global, read before anything moves it, so the pointer can be put back on quit.
    let initialCursor = CGEvent(source: nil)?.location

    FileManager.default.createFile(atPath: clicksFile, contents: nil)
    guard let log = FileHandle(forWritingAtPath: clicksFile) else {
        FileHandle.standardError.write(Data("click-target: cannot open \(clicksFile)\n".utf8))
        exit(1)
    }

    // 400x300 of content whose top-left corner is at (120, 240) in CG global space of the main display.
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 900
    let contentSize = CGSize(width: 400, height: 300)
    let contentRect = CGRect(
        x: 120, y: primaryHeight - 240 - contentSize.height, width: contentSize.width, height: contentSize.height)
    let window = TargetWindow(
        contentRect: contentRect, styleMask: [.titled], backing: .buffered, defer: false)
    window.title = "AutoClicker Live Check Target"
    window.level = .floating
    window.isReleasedWhenClosed = false
    let view = TargetView(frame: CGRect(origin: .zero, size: contentSize))
    window.contentView = view
    window.log = log
    window.onClick = { [weak window, weak view] screenPoint in
        guard let window, let view else { return }
        let inWindow = window.convertPoint(fromScreen: screenPoint)
        view.dots.append(view.convert(inWindow, from: nil))
        view.needsDisplay = true
    }
    window.orderFrontRegardless()
    app.activate(ignoringOtherApps: true)

    let frames = TargetFrames(
        window: Rect(cgRect(fromAppKit: window.frame)),
        content: Rect(cgRect(fromAppKit: window.contentRect(forFrameRect: window.frame))),
        pid: getpid())
    do {
        try JSONEncoder().encode(frames).write(to: URL(fileURLWithPath: frameFile), options: .atomic)
    } catch {
        FileHandle.standardError.write(Data("click-target: cannot write \(frameFile): \(error)\n".utf8))
        exit(1)
    }

    func finish() -> Never {
        try? log.close()
        if let initialCursor {
            CGWarpMouseCursorPosition(initialCursor)
        }
        exit(0)
    }
    // Signals arrive on the main queue, so quitting never races the event handling above.
    var sources: [DispatchSourceSignal] = []
    for signalNumber in [SIGTERM, SIGINT] {
        signal(signalNumber, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
        source.setEventHandler { finish() }
        source.resume()
        sources.append(source)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { finish() }
    withExtendedLifetime(sources) {
        app.run()
    }
    finish()
}

// MARK: - Verifying

func verify(clicksFile: String, resultFile: String) -> Never {
    var failures = 0
    func check(_ passed: Bool, _ name: String, _ detail: String) {
        print("\(passed ? "PASS" : "FAIL")  \(name): \(detail)")
        if !passed { failures += 1 }
    }

    guard let resultData = FileManager.default.contents(atPath: resultFile),
        let result = try? JSONDecoder().decode(AppResult.self, from: resultData)
    else {
        print("FAIL  result file: cannot read \(resultFile)")
        exit(1)
    }
    let clicks =
        (try? String(contentsOfFile: clicksFile, encoding: .utf8))?
        .split(separator: "\n")
        .compactMap { try? JSONDecoder().decode(RecordedClick.self, from: Data($0.utf8)) } ?? []

    for note in result.notes {
        print("note  \(note)")
    }
    check(result.accessibilityTrusted, "accessibility", result.accessibilityTrusted ? "trusted" : "NOT trusted")
    print("info  add point: \(result.addPoint.method)")
    for (index, point) in result.addPoint.points.enumerated() {
        let appended = point.appended.map { String(format: "(%.1f, %.1f)", $0.x, $0.y) } ?? "nothing"
        check(
            point.passed, "add point \(index + 1)",
            String(
                format: "cursor at (%.0f, %.0f), appended %@ with delay %@ ms after a %.2f s countdown, off by %@",
                point.requested.x, point.requested.y, appended, point.delayMilliseconds.map(String.init) ?? "-",
                point.countdownSeconds, point.distance.map { String(format: "%.2f pt", $0) } ?? "-"))
    }
    check(
        result.addPoint.passed && result.addPoint.points.count == 3, "add point",
        "\(result.addPoint.points.filter(\.passed).count) of 3 points")
    if let profiles = result.profiles {
        print("info  profiles: \(profiles.method)")
        check(
            profiles.itemsBefore.filter(\.isChecked).map(\.title) == [profiles.activeBefore ?? ""], "profiles submenu",
            "items [\(describe(profiles.itemsBefore))], active profile \(profiles.activeBefore ?? "none")")
        check(
            profiles.activeAfter == profiles.chosen && profiles.configurationMatchesChosen, "apply from submenu",
            "chose \(profiles.chosen): active profile now \(profiles.activeAfter ?? "none"), configuration "
                + (profiles.configurationMatchesChosen ? "matches it" : "DIFFERS"))
        check(
            profiles.passed, "submenu after applying",
            "items [\(describe(profiles.itemsAfter))]")
    } else {
        check(false, "profiles", "the app did not get to the profiles step")
    }
    guard let run = result.run, run.started else {
        check(false, "run", "the app did not start the live run (see its log)")
        exit(1)
    }
    check(
        run.countedClicks == run.expectedClicks, "app counter",
        "\(run.countedClicks) of \(run.expectedClicks), stop reason \(run.stopReason ?? "none")")
    check(
        clicks.count == run.expectedClicks, "click count",
        "\(clicks.count) clicks received, \(run.expectedClicks) expected")

    let points = run.points.map { CGPoint(x: $0.x, y: $0.y) }
    var order: [Int] = []
    var maxDistance = 0.0
    var distances: [Double] = []
    for click in clicks {
        let location = CGPoint(x: click.x, y: click.y)
        let nearest = points.indices.min { lhs, rhs in
            hypot(points[lhs].x - location.x, points[lhs].y - location.y)
                < hypot(points[rhs].x - location.x, points[rhs].y - location.y)
        }
        guard let nearest else { continue }
        order.append(nearest + 1)
        let distance = hypot(points[nearest].x - location.x, points[nearest].y - location.y)
        distances.append(distance)
        maxDistance = max(maxDistance, distance)
    }
    let expectedOrder = (0..<clicks.count).map { $0 % max(points.count, 1) + 1 }
    check(
        !order.isEmpty && order == expectedOrder, "order",
        order.map(String.init).joined(separator: ","))
    let limit = Double(run.positionOffset) + 1
    check(
        !distances.isEmpty && maxDistance <= limit, "offset",
        String(
            format: "max distance %.2f pt (limit %.0f), min %.2f, mean %.2f", maxDistance, limit,
            distances.min() ?? 0, distances.isEmpty ? 0 : distances.reduce(0, +) / Double(distances.count)))
    let expectedModifiers = Set(run.modifiers)
    let modifierSets = clicks.map { Set($0.modifiers) }
    check(
        !clicks.isEmpty && modifierSets.allSatisfy { $0 == expectedModifiers }, "modifiers",
        "expected \(run.modifiers.sorted()), received "
            + Set(modifierSets.map { $0.sorted().joined(separator: "+") }).sorted().map { "[\($0)]" }
            .joined(separator: " "))
    check(
        !clicks.isEmpty && clicks.allSatisfy { $0.clickCount == 1 && $0.clickState == 1 }, "click count per event",
        "clickCount " + Set(clicks.map(\.clickCount)).sorted().map(String.init).joined(separator: ",")
            + ", click state " + Set(clicks.map(\.clickState)).sorted().map(String.init).joined(separator: ","))
    check(
        !clicks.isEmpty && clicks.allSatisfy { $0.type == "leftMouseDown" && $0.button == 0 }, "button",
        Set(clicks.map { "\($0.type) button \($0.button)" }).sorted().joined(separator: ", "))
    if clicks.count > 1 {
        let gaps = zip(clicks.dropFirst(), clicks).map { ($0.time - $1.time) * 1000 }
        print(
            String(
                format: "info  spacing between clicks: min %.0f ms, max %.0f ms, mean %.0f ms",
                gaps.min() ?? 0, gaps.max() ?? 0, gaps.reduce(0, +) / Double(gaps.count)))
    }
    print(failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECK(S) FAILED")
    exit(failures == 0 ? 0 : 1)
}

// MARK: - Entry point

let arguments = CommandLine.arguments
switch (arguments.count > 1 ? arguments[1] : "", arguments.count) {
case ("record", 5):
    MainActor.assumeIsolated {
        record(frameFile: arguments[2], clicksFile: arguments[3], seconds: Double(arguments[4]) ?? 60)
    }
case ("verify", 4):
    verify(clicksFile: arguments[2], resultFile: arguments[3])
default:
    FileHandle.standardError.write(
        Data("usage: click-target record FRAME_FILE CLICKS_FILE SECONDS | verify CLICKS_FILE RESULT_FILE\n".utf8))
    exit(64)
}
