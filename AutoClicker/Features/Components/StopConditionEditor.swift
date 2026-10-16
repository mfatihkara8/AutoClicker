/// Editing glue between the stop-condition card's controls and a `StopCondition`.
///
/// The card edits a kind plus either a click count or an hours/minutes/seconds duration. Switching the kind starts
/// from a sensible default; setting a value that does not belong to the current kind is ignored. All setters clamp,
/// so the stored limit is never negative and never zero.
struct StopConditionEditor: Equatable {
    /// The kinds of stop condition the card offers.
    enum Kind: CaseIterable, Hashable {
        case never
        case afterClicks
        case afterDuration
    }

    static let defaultClicks = 100
    static let defaultDurationSeconds = 60
    static let clicksRange = 1...999_999_999
    static let hoursRange = 0...999
    static let minutesRange = 0...59
    static let secondsRange = 0...59
    /// A zero duration would end the run after its first click, so the shortest duration is one second.
    static let minimumDurationSeconds = 1

    /// The edited stop condition.
    private(set) var condition: StopCondition

    init(condition: StopCondition) {
        self.condition = condition
    }

    var kind: Kind {
        get {
            switch condition {
            case .never: .never
            case .afterClicks: .afterClicks
            case .afterDuration: .afterDuration
            }
        }
        set {
            guard newValue != kind else { return }
            switch newValue {
            case .never:
                condition = .never
            case .afterClicks:
                condition = .afterClicks(Self.defaultClicks)
            case .afterDuration:
                condition = .afterDuration(.seconds(Self.defaultDurationSeconds))
            }
        }
    }

    /// The click limit, or the default limit while another kind is selected.
    var clicks: Int {
        get {
            guard case .afterClicks(let limit) = condition else { return Self.defaultClicks }
            return max(0, limit)
        }
        set {
            guard kind == .afterClicks else { return }
            condition = .afterClicks(newValue.clamped(to: Self.clicksRange))
        }
    }

    var hours: Int {
        get { totalSeconds / 3_600 }
        set { setDuration(hours: newValue, minutes: minutes, seconds: seconds) }
    }

    var minutes: Int {
        get { totalSeconds % 3_600 / 60 }
        set { setDuration(hours: hours, minutes: newValue, seconds: seconds) }
    }

    var seconds: Int {
        get { totalSeconds % 60 }
        set { setDuration(hours: hours, minutes: minutes, seconds: newValue) }
    }

    /// The duration limit in whole seconds, or the default duration while another kind is selected. Fractions of a
    /// second are dropped because the card edits whole seconds only.
    private var totalSeconds: Int {
        guard case .afterDuration(let limit) = condition else { return Self.defaultDurationSeconds }
        return Int(clamping: max(0, limit.components.seconds))
    }

    private mutating func setDuration(hours: Int, minutes: Int, seconds: Int) {
        guard kind == .afterDuration else { return }
        let total =
            hours.clamped(to: Self.hoursRange) * 3_600
            + minutes.clamped(to: Self.minutesRange) * 60
            + seconds.clamped(to: Self.secondsRange)
        condition = .afterDuration(.seconds(max(Self.minimumDurationSeconds, total)))
    }
}
