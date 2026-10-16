import Testing

@testable import AutoClicker

/// These tests only exercise paths that never call `RegisterEventHotKey`, so no real hotkey is registered.
@MainActor
struct CarbonHotkeyManagerTests {
    @Test func newManagerHasNothingRegistered() {
        let manager = CarbonHotkeyManager()
        #expect(!manager.isRegistered(.f6))
        #expect(!manager.isRegistered(.escape))
    }

    @Test func unregisteringWhatIsNotRegisteredIsANoOp() {
        let manager = CarbonHotkeyManager()
        manager.unregister(.escape)
        manager.unregisterAll()
        #expect(!manager.isRegistered(.escape))
    }
}
