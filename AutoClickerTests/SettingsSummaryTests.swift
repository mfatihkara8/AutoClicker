import CoreGraphics
import Foundation
import Testing

@testable import AutoClicker

struct SettingsSummaryTests {
    private static let locale = Locale(identifier: "en_US")

    private func summary(
        clickType: ClickType = .left,
        modifiers: ClickModifiers = [],
        interval: ClickInterval = ClickInterval(milliseconds: 100),
        target: ClickTarget = .currentCursor,
        stopCondition: StopCondition = .never
    ) -> SettingsSummary {
        SettingsSummary(
            configuration: ClickConfiguration(
                clickType: clickType,
                interval: interval,
                target: target,
                stopCondition: stopCondition,
                modifiers: modifiers),
            locale: Self.locale)
    }

    // MARK: - Whole line

    @Test func defaultConfigurationReadsAsOneLine() {
        let text = SettingsSummary(configuration: .default, locale: Self.locale).text
        #expect(text == "Left click · 100 ms · Cursor · Never stops")
    }

    @Test func specExampleWithShiftHeld() {
        #expect(summary(modifiers: .shift).text == "⇧-Left click · 100 ms · Cursor · Never stops")
    }

    @Test func everyPartIsShownInOrder() {
        let text = summary(
            clickType: .double,
            modifiers: [.command, .shift],
            interval: ClickInterval(seconds: 1, milliseconds: 500, jitterMilliseconds: 50),
            target: .fixed(CGPoint(x: 1640, y: 400)),
            stopCondition: .afterClicks(1000)
        ).text
        #expect(text == "⇧⌘-Double click · 1 sec, 500 ms ± 50 ms · At 1640, 400 · Stops after 1,000 clicks")
    }

    // MARK: - Click

    @Test(arguments: ClickType.allCases)
    func plainClickUsesTheClickName(type: ClickType) {
        #expect(summary(clickType: type).clickText == type.clickName)
    }

    @Test func modifiersAreShownInMenuOrder() {
        let text = summary(clickType: .right, modifiers: [.command, .option, .shift, .control]).clickText
        #expect(text == "⌃⌥⇧⌘-Right click")
    }

    // MARK: - Interval

    @Test func intervalCombinesItsComponents() {
        let interval = ClickInterval(hours: 1, minutes: 2, seconds: 3, milliseconds: 250)
        #expect(summary(interval: interval).intervalText == "1 hr, 2 min, 3 sec, 250 ms")
    }

    @Test func zeroIntervalShowsTheEffectiveMinimum() {
        #expect(summary(interval: ClickInterval()).intervalText == "1 ms")
    }

    @Test func jitterIsShownWhenItApplies() {
        let interval = ClickInterval(milliseconds: 100, jitterMilliseconds: 20)
        #expect(summary(interval: interval).intervalText == "100 ms ± 20 ms")
    }

    @Test func jitterIsCappedLikeTheEngine() {
        // (10 ms - 1 ms) / 2 = 4 ms is what the scheduler actually applies.
        let interval = ClickInterval(milliseconds: 10, jitterMilliseconds: 50)
        #expect(summary(interval: interval).intervalText == "10 ms ± 4 ms")
    }

    @Test func jitterIsHiddenWhenTheIntervalIsTooShort() {
        let interval = ClickInterval(milliseconds: 1, jitterMilliseconds: 50)
        #expect(summary(interval: interval).intervalText == "1 ms")
    }

    // MARK: - Target

    @Test func cursorTarget() {
        #expect(summary(target: .currentCursor).targetText == "Cursor")
    }

    @Test func fixedTargetShowsWholePointsWithoutGrouping() {
        #expect(summary(target: .fixed(CGPoint(x: 2560.4, y: 1439.6))).targetText == "At 2560, 1440")
    }

    @Test func fixedTargetShowsNegativeCoordinates() {
        #expect(summary(target: .fixed(CGPoint(x: -1920, y: 0))).targetText == "At -1920, 0")
    }

    // MARK: - Stop condition

    @Test func neverStops() {
        #expect(summary(stopCondition: .never).stopConditionText == "Never stops")
    }

    @Test func stopsAfterOneClickUsesTheSingular() {
        #expect(summary(stopCondition: .afterClicks(1)).stopConditionText == "Stops after 1 click")
    }

    @Test func stopsAfterClicksIsFormatted() {
        #expect(summary(stopCondition: .afterClicks(12_345)).stopConditionText == "Stops after 12,345 clicks")
    }

    @Test func stopsAfterDuration() {
        let text = summary(stopCondition: .afterDuration(.seconds(90))).stopConditionText
        #expect(text == "Stops after 1 min, 30 sec")
    }

    @Test func stopsAfterHours() {
        let text = summary(stopCondition: .afterDuration(.seconds(5400))).stopConditionText
        #expect(text == "Stops after 1 hr, 30 min")
    }
}
