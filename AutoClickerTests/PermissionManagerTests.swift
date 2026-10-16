import Foundation
import Testing

@testable import AutoClicker

@MainActor
struct PermissionManagerTests {
    /// Short enough to keep the suite fast; the tests never rely on wall-clock timing for correctness.
    private let pollInterval = Duration.milliseconds(5)

    private func makeManager(
        checker: MockPermissionChecker,
        openURL: @escaping @MainActor (URL) -> Void = { _ in }
    ) -> PermissionManager {
        PermissionManager(checker: checker, pollInterval: pollInterval, openURL: openURL)
    }

    @Test func initReadsTrustWithoutPrompting() {
        let checker = MockPermissionChecker(isTrusted: false)
        let manager = makeManager(checker: checker)

        #expect(manager.isTrusted == false)
        #expect(checker.isTrustedReadCount == 1)
        #expect(checker.requestTrustCallCount == 0)
        #expect(manager.isPolling == false)
    }

    @Test func pollingPicksUpGrantAndThenStops() async throws {
        let checker = MockPermissionChecker(isTrusted: false)
        let manager = makeManager(checker: checker)
        // Read 1 is init, read 2 is the immediate check in startMonitoring, reads 3+ are polls.
        checker.grantTrust(atRead: 5)

        manager.startMonitoring()
        #expect(manager.isPolling)

        await manager.waitForPollingToFinish()

        #expect(manager.isTrusted)
        #expect(manager.isPolling == false)
        #expect(checker.isTrustedReadCount == 5)

        // Several intervals later, nothing has read the checker again.
        try await Task.sleep(for: pollInterval * 10)
        #expect(checker.isTrustedReadCount == 5)
        #expect(checker.requestTrustCallCount == 0)
    }

    @Test func noPollingWhenAlreadyTrusted() async throws {
        let checker = MockPermissionChecker(isTrusted: true)
        let manager = makeManager(checker: checker)

        manager.startMonitoring()

        #expect(manager.isTrusted)
        #expect(manager.isPolling == false)
        try await Task.sleep(for: pollInterval * 10)
        #expect(checker.isTrustedReadCount == 2)
    }

    @Test func noPollingBeforeMonitoringStarts() async throws {
        let checker = MockPermissionChecker(isTrusted: false)
        let manager = makeManager(checker: checker)

        try await Task.sleep(for: pollInterval * 10)

        #expect(manager.isPolling == false)
        #expect(checker.isTrustedReadCount == 1)
    }

    @Test func stopMonitoringCancelsPolling() async throws {
        let checker = MockPermissionChecker(isTrusted: false)
        let manager = makeManager(checker: checker)

        manager.startMonitoring()
        #expect(manager.isPolling)

        manager.stopMonitoring()
        #expect(manager.isPolling == false)
        let readsAtStop = checker.isTrustedReadCount

        try await Task.sleep(for: pollInterval * 10)
        #expect(checker.isTrustedReadCount == readsAtStop)
        #expect(manager.isTrusted == false)
    }

    @Test func startMonitoringTwiceKeepsSinglePollingTask() async {
        let checker = MockPermissionChecker(isTrusted: false)
        let manager = makeManager(checker: checker)
        checker.grantTrust(atRead: 4)

        manager.startMonitoring()
        manager.startMonitoring()
        await manager.waitForPollingToFinish()

        // Init, two immediate checks, then exactly one poll; a second task would add reads.
        #expect(manager.isTrusted)
        #expect(checker.isTrustedReadCount == 4)
    }

    @Test func requestPermissionCallsRequestTrustOnce() {
        let checker = MockPermissionChecker(isTrusted: false)
        let manager = makeManager(checker: checker)

        manager.requestPermission()

        #expect(checker.requestTrustCallCount == 1)
    }

    @Test func requestPermissionDoesNotPollWhenNotMonitoring() {
        let checker = MockPermissionChecker(isTrusted: false)
        let manager = makeManager(checker: checker)

        manager.requestPermission()

        #expect(manager.isPolling == false)
    }

    @Test func refreshDetectsRevocationAndResumesPollingWhileMonitoring() {
        let checker = MockPermissionChecker(isTrusted: true)
        let manager = makeManager(checker: checker)
        manager.startMonitoring()
        #expect(manager.isPolling == false)

        checker.isTrusted = false
        manager.refresh()

        #expect(manager.isTrusted == false)
        #expect(manager.isPolling)
        manager.stopMonitoring()
    }

    @Test func refreshWithoutMonitoringDoesNotPoll() {
        let checker = MockPermissionChecker(isTrusted: true)
        let manager = makeManager(checker: checker)

        checker.isTrusted = false
        manager.refresh()

        #expect(manager.isTrusted == false)
        #expect(manager.isPolling == false)
        #expect(checker.requestTrustCallCount == 0)
    }

    @Test func openAccessibilitySettingsOpensPrivacyPane() throws {
        let checker = MockPermissionChecker()
        var openedURLs: [URL] = []
        let manager = makeManager(checker: checker) { openedURLs.append($0) }

        manager.openAccessibilitySettings()

        let expected = try #require(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"))
        #expect(openedURLs == [expected])
    }
}
