import Testing

@testable import AutoClicker

@MainActor
struct WindowNavigationTests {
    @Test func startsOnMain() {
        #expect(WindowNavigation().selectedTab == .main)
    }

    @Test func resetGoesBackToMain() {
        let navigation = WindowNavigation()
        navigation.selectedTab = .about
        navigation.reset()
        #expect(navigation.selectedTab == .main)
    }

    @Test func tabsAreInSpecOrder() {
        #expect(AppTab.allCases == [.main, .click, .shortcuts, .about])
    }
}
