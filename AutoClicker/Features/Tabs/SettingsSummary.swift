import CoreGraphics
import Foundation

/// The one-line summary of the click settings on the Main tab, such as "⇧-Left click · 100 ms · Cursor · Never stops".
///
/// A plain value so the wording can be unit tested without building a view. The summary describes what a run will
/// actually do, so it shows the effective interval (never below 1 ms) and the effective jitter (none when the interval
/// is too short for it), not the raw input.
struct SettingsSummary: Equatable {
    let configuration: ClickConfiguration
    /// The locale used for numbers and durations; injected so tests do not depend on the machine's settings.
    var locale: Locale = .current

    /// The parts joined into one line.
    var text: String {
        [clickText, intervalText, targetText, stopConditionText].joined(separator: " · ")
    }

    /// The click with its held modifiers, such as "Left click" or "⇧⌘-Double click".
    var clickText: String {
        let clickType = configuration.clickType
        // Same wording as the menu bar status, so a modified click reads the same everywhere.
        return MenuBarPresentation.modifiedClickName(clickType: clickType, modifiers: configuration.modifiers)
            ?? clickType.clickName
    }

    /// The interval between clicks, such as "100 ms", "1 min, 30 sec" or "100 ms ± 20 ms".
    var intervalText: String {
        let interval = configuration.interval
        let duration = formatted(interval.duration)
        let jitter = interval.effectiveJitterMilliseconds
        guard jitter > 0 else { return duration }
        let jitterText = formatted(.milliseconds(jitter))
        return String(
            localized: "\(duration) ± \(jitterText)",
            comment: "Settings summary: the click interval with its random jitter, such as 100 ms ± 20 ms.")
    }

    /// Where the clicks land, such as "Cursor" or "At 640, 400".
    var targetText: String {
        switch configuration.target {
        case .currentCursor:
            return String(
                localized: "Cursor", comment: "Settings summary: every click lands wherever the cursor is.")
        case .fixed(let point):
            let x = coordinate(point.x)
            let y = coordinate(point.y)
            return String(
                localized: "At \(x), \(y)",
                comment: "Settings summary: every click lands on a fixed point; the arguments are its X and Y.")
        }
    }

    /// When the run ends on its own, such as "Never stops", "Stops after 100 clicks" or "Stops after 1 min".
    var stopConditionText: String {
        switch configuration.stopCondition {
        case .never:
            return String(
                localized: "Never stops", comment: "Settings summary: the run continues until it is stopped.")
        case .afterClicks(let limit):
            let count = limit.formatted(.number.locale(locale))
            if limit == 1 {
                return String(
                    localized: "Stops after \(count) click",
                    comment: "Settings summary: the run stops after exactly one click; the argument is the count.")
            }
            return String(
                localized: "Stops after \(count) clicks",
                comment: "Settings summary: the run stops after this many clicks; the argument is the count.")
        case .afterDuration(let limit):
            let duration = formatted(limit)
            return String(
                localized: "Stops after \(duration)",
                comment: "Settings summary: the run stops after this much time, such as 1 min, 30 sec.")
        }
    }

    private func formatted(_ duration: Duration) -> String {
        duration.formatted(
            .units(
                allowed: [.hours, .minutes, .seconds, .milliseconds],
                width: .abbreviated,
                zeroValueUnits: .hide
            )
            .locale(locale))
    }

    /// A coordinate in whole points, without grouping, as the target fields show it.
    private func coordinate(_ value: CGFloat) -> String {
        Double(value).formatted(.number.precision(.fractionLength(0)).grouping(.never).locale(locale))
    }
}
