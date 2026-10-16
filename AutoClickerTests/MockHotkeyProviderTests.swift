import Testing

@testable import AutoClicker

@MainActor
struct MockHotkeyProviderTests {
    @Test func registerRecordsTheHotkey() throws {
        let provider = MockHotkeyProvider()
        try provider.register(.f6) {}

        #expect(provider.isRegistered(.f6))
        #expect(!provider.isRegistered(.escape))
        #expect(provider.registeredHotkeys == [.f6])
        #expect(provider.registerCalls == [.f6])
    }

    @Test func simulatePressCallsTheHandler() throws {
        let provider = MockHotkeyProvider()
        var presses = 0
        try provider.register(.f6) { presses += 1 }

        #expect(provider.simulatePress(.f6))
        #expect(provider.simulatePress(.f6))
        #expect(presses == 2)
    }

    @Test func simulatePressOfUnregisteredHotkeyDoesNothing() throws {
        let provider = MockHotkeyProvider()
        var presses = 0
        try provider.register(.f6) { presses += 1 }

        #expect(!provider.simulatePress(.escape))
        #expect(presses == 0)
    }

    @Test func registeringTwiceReplacesTheHandler() throws {
        let provider = MockHotkeyProvider()
        var calls: [String] = []
        try provider.register(.f6) { calls.append("first") }
        try provider.register(.f6) { calls.append("second") }

        provider.simulatePress(.f6)
        #expect(calls == ["second"])
        #expect(provider.registeredHotkeys == [.f6])
    }

    @Test func unregisterRemovesOnlyThatHotkey() throws {
        let provider = MockHotkeyProvider()
        var f6Presses = 0
        var escapePresses = 0
        try provider.register(.f6) { f6Presses += 1 }
        try provider.register(.escape) { escapePresses += 1 }

        provider.unregister(.escape)

        #expect(!provider.simulatePress(.escape))
        #expect(provider.simulatePress(.f6))
        #expect(escapePresses == 0)
        #expect(f6Presses == 1)
        #expect(provider.unregisterCalls == [.escape])
    }

    @Test func unregisteringWhatIsNotRegisteredIsANoOp() throws {
        let provider = MockHotkeyProvider()
        try provider.register(.f6) {}

        provider.unregister(.escape)

        #expect(provider.registeredHotkeys == [.f6])
    }

    @Test func unregisterAllRemovesEverything() throws {
        let provider = MockHotkeyProvider()
        try provider.register(.f6) {}
        try provider.register(.escape) {}

        provider.unregisterAll()

        #expect(provider.registeredHotkeys.isEmpty)
        #expect(!provider.simulatePress(.f6))
        #expect(provider.unregisterAllCallCount == 1)
    }

    @Test func hotkeyCanBeRegisteredAgainAfterUnregistering() throws {
        let provider = MockHotkeyProvider()
        var presses = 0
        try provider.register(.escape) { presses += 1 }
        provider.unregister(.escape)
        try provider.register(.escape) { presses += 1 }

        provider.simulatePress(.escape)
        #expect(presses == 1)
    }

    @Test func registrationErrorIsThrownAndNothingIsRegistered() {
        let provider = MockHotkeyProvider()
        let error = HotkeyRegistrationError.registrationFailed(.f6, status: -9878)
        provider.registrationErrors[.f6] = error

        #expect(throws: error) {
            try provider.register(.f6) {}
        }
        #expect(!provider.isRegistered(.f6))
        #expect(provider.registerCalls == [.f6])
    }
}
