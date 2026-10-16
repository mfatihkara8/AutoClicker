import Testing

@testable import AutoClicker

struct ClickIntervalEditorTests {
    @Test func readsTheStoredComponents() {
        let editor = ClickIntervalEditor(
            interval: ClickInterval(hours: 1, minutes: 2, seconds: 3, milliseconds: 4, jitterMilliseconds: 5))
        #expect(editor.hours == 1)
        #expect(editor.minutes == 2)
        #expect(editor.seconds == 3)
        #expect(editor.milliseconds == 4)
        #expect(editor.jitterMilliseconds == 5)
    }

    @Test func showsNegativeStoredComponentsAsZero() {
        let editor = ClickIntervalEditor(
            interval: ClickInterval(hours: -1, minutes: -2, seconds: -3, milliseconds: -4, jitterMilliseconds: -5))
        #expect(editor.hours == 0)
        #expect(editor.minutes == 0)
        #expect(editor.seconds == 0)
        #expect(editor.milliseconds == 0)
        #expect(editor.jitterMilliseconds == 0)
    }

    @Test func settersClampNegativeInputToZero() {
        var editor = ClickIntervalEditor(
            interval: ClickInterval(hours: 1, minutes: 1, seconds: 1, milliseconds: 1, jitterMilliseconds: 1))
        editor.hours = -5
        editor.minutes = -5
        editor.seconds = -5
        editor.milliseconds = -5
        editor.jitterMilliseconds = -5
        #expect(editor.interval == ClickInterval())
    }

    @Test func settersClampLargeInputToTheUpperBound() {
        var editor = ClickIntervalEditor(interval: ClickInterval())
        editor.hours = 10_000
        editor.minutes = 75
        editor.seconds = 60
        editor.milliseconds = 1_500
        editor.jitterMilliseconds = Int.max
        #expect(
            editor.interval
                == ClickInterval(
                    hours: 999, minutes: 59, seconds: 59, milliseconds: 999, jitterMilliseconds: 3_600_000))
    }

    @Test func setterKeepsTheOtherComponents() {
        var editor = ClickIntervalEditor(interval: ClickInterval(seconds: 2, milliseconds: 100))
        editor.milliseconds = 250
        #expect(editor.interval == ClickInterval(seconds: 2, milliseconds: 250))
    }

    @Test func jitterWithinTheCapIsNotCapped() {
        let editor = ClickIntervalEditor(interval: ClickInterval(milliseconds: 101, jitterMilliseconds: 50))
        #expect(!editor.isJitterCapped)
        #expect(editor.effectiveJitterMilliseconds == 50)
    }

    @Test func jitterAboveTheCapIsReportedAsCapped() {
        let editor = ClickIntervalEditor(interval: ClickInterval(milliseconds: 100, jitterMilliseconds: 80))
        #expect(editor.isJitterCapped)
        #expect(editor.effectiveJitterMilliseconds == 49)
    }

    @Test func zeroJitterIsNeverCapped() {
        let editor = ClickIntervalEditor(interval: ClickInterval(milliseconds: 1))
        #expect(!editor.isJitterCapped)
    }

    @Test func jitterAtTheMinimumIntervalIsCappedToZero() {
        let editor = ClickIntervalEditor(interval: ClickInterval(milliseconds: 1, jitterMilliseconds: 10))
        #expect(editor.isJitterCapped)
        #expect(editor.effectiveJitterMilliseconds == 0)
    }

    @Test func zeroIntervalIsRaisedToTheMinimum() {
        #expect(ClickIntervalEditor(interval: ClickInterval()).isRaisedToMinimum)
        #expect(!ClickIntervalEditor(interval: ClickInterval(milliseconds: 1)).isRaisedToMinimum)
        #expect(!ClickIntervalEditor(interval: ClickInterval(hours: 1)).isRaisedToMinimum)
    }
}
