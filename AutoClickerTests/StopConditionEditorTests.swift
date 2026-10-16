import Testing

@testable import AutoClicker

struct StopConditionEditorTests {
    @Test func readsTheKind() {
        #expect(StopConditionEditor(condition: .never).kind == .never)
        #expect(StopConditionEditor(condition: .afterClicks(5)).kind == .afterClicks)
        #expect(StopConditionEditor(condition: .afterDuration(.seconds(5))).kind == .afterDuration)
    }

    @Test func switchingKindStartsFromTheDefaults() {
        var editor = StopConditionEditor(condition: .never)
        editor.kind = .afterClicks
        #expect(editor.condition == .afterClicks(StopConditionEditor.defaultClicks))
        editor.kind = .afterDuration
        #expect(editor.condition == .afterDuration(.seconds(StopConditionEditor.defaultDurationSeconds)))
        editor.kind = .never
        #expect(editor.condition == .never)
    }

    @Test func selectingTheSameKindKeepsTheValue() {
        var editor = StopConditionEditor(condition: .afterClicks(42))
        editor.kind = .afterClicks
        #expect(editor.condition == .afterClicks(42))
    }

    @Test func clicksAreReadAndClamped() {
        var editor = StopConditionEditor(condition: .afterClicks(42))
        #expect(editor.clicks == 42)
        editor.clicks = 7
        #expect(editor.condition == .afterClicks(7))
        editor.clicks = 0
        #expect(editor.condition == .afterClicks(1))
        editor.clicks = -3
        #expect(editor.condition == .afterClicks(1))
        editor.clicks = Int.max
        #expect(editor.condition == .afterClicks(StopConditionEditor.clicksRange.upperBound))
    }

    @Test func negativeStoredClicksAreShownAsZero() {
        #expect(StopConditionEditor(condition: .afterClicks(-4)).clicks == 0)
    }

    @Test func valuesOfAnotherKindAreIgnored() {
        var editor = StopConditionEditor(condition: .never)
        editor.clicks = 5
        editor.hours = 1
        #expect(editor.condition == .never)

        editor = StopConditionEditor(condition: .afterClicks(3))
        editor.minutes = 2
        #expect(editor.condition == .afterClicks(3))

        editor = StopConditionEditor(condition: .afterDuration(.seconds(9)))
        editor.clicks = 5
        #expect(editor.condition == .afterDuration(.seconds(9)))
    }

    @Test func otherKindsShowTheDefaults() {
        let editor = StopConditionEditor(condition: .never)
        #expect(editor.clicks == StopConditionEditor.defaultClicks)
        #expect(editor.hours == 0)
        #expect(editor.minutes == 1)
        #expect(editor.seconds == 0)
    }

    @Test func durationIsSplitIntoHoursMinutesAndSeconds() {
        let editor = StopConditionEditor(condition: .afterDuration(.seconds(3_723)))
        #expect(editor.hours == 1)
        #expect(editor.minutes == 2)
        #expect(editor.seconds == 3)
    }

    @Test func fractionalSecondsAreDropped() {
        let editor = StopConditionEditor(condition: .afterDuration(.milliseconds(2_900)))
        #expect(editor.seconds == 2)
    }

    @Test func negativeDurationIsShownAsZero() {
        let editor = StopConditionEditor(condition: .afterDuration(.seconds(-30)))
        #expect(editor.hours == 0)
        #expect(editor.minutes == 0)
        #expect(editor.seconds == 0)
    }

    @Test func settingAComponentKeepsTheOthers() {
        var editor = StopConditionEditor(condition: .afterDuration(.seconds(3_723)))
        editor.minutes = 30
        #expect(editor.condition == .afterDuration(.seconds(3_600 + 30 * 60 + 3)))
        editor.hours = 0
        #expect(editor.condition == .afterDuration(.seconds(30 * 60 + 3)))
        editor.seconds = 0
        #expect(editor.condition == .afterDuration(.seconds(30 * 60)))
    }

    @Test func durationComponentsAreClamped() {
        var editor = StopConditionEditor(condition: .afterDuration(.seconds(1)))
        editor.hours = 5_000
        editor.minutes = 99
        editor.seconds = -1
        #expect(editor.condition == .afterDuration(.seconds(999 * 3_600 + 59 * 60)))
    }

    @Test func zeroDurationIsRaisedToTheMinimum() {
        var editor = StopConditionEditor(condition: .afterDuration(.seconds(60)))
        editor.minutes = 0
        #expect(editor.condition == .afterDuration(.seconds(StopConditionEditor.minimumDurationSeconds)))
    }
}
