import Testing

@testable import AutoClicker

/// Smoke test proving the test target builds against the app module.
/// Real suites (ClickEngineTests, ClickSchedulerTests, ...) arrive with M1–M5.
struct AutoClickerTests {
    @Test func example() async throws {
        #expect(Bool(true))
    }
}
