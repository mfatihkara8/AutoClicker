import Foundation
import Observation

/// Publishes the Accessibility trust state to the UI and keeps it current.
///
/// macOS sends no notification when Accessibility trust changes, so the manager polls the
/// checker. It polls only while monitoring is on (the window is visible) and trust is missing,
/// and it stops the moment trust is detected, so the app stays at ~0% CPU when idle.
@Observable @MainActor
final class PermissionManager {
    /// The System Settings pane that lists apps with Accessibility access.
    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    /// Whether the app is currently trusted for Accessibility.
    private(set) var isTrusted: Bool

    @ObservationIgnored private let checker: any PermissionChecking
    @ObservationIgnored private let pollInterval: Duration
    @ObservationIgnored private let openURL: @MainActor (URL) -> Void
    @ObservationIgnored private var isMonitoring = false
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    /// Creates a manager and reads the current trust state once, without prompting.
    ///
    /// - Parameters:
    ///   - checker: The adapter that reads and requests Accessibility trust.
    ///   - pollInterval: How often trust is re-checked while it is missing.
    ///   - openURL: Opens a URL; injected so `Core` needs no AppKit and tests open nothing.
    init(
        checker: any PermissionChecking,
        pollInterval: Duration = .seconds(1),
        openURL: @escaping @MainActor (URL) -> Void
    ) {
        self.checker = checker
        self.pollInterval = pollInterval
        self.openURL = openURL
        self.isTrusted = checker.isTrusted
    }

    deinit {
        pollingTask?.cancel()
    }

    /// Whether a polling task is currently running.
    var isPolling: Bool {
        pollingTask != nil
    }

    /// Starts keeping `isTrusted` current. Call it when the window becomes visible.
    ///
    /// Re-reads trust right away, then polls only if trust is still missing. Calling it again
    /// while monitoring is a no-op apart from the immediate re-read.
    func startMonitoring() {
        isMonitoring = true
        updateTrust()
        startPollingIfNeeded()
    }

    /// Stops monitoring and cancels any polling. Call it when the window is hidden.
    func stopMonitoring() {
        isMonitoring = false
        stopPolling()
    }

    /// Shows the system Accessibility prompt. Call it only from an explicit user action.
    func requestPermission() {
        checker.requestTrust()
        updateTrust()
        startPollingIfNeeded()
    }

    /// Re-reads trust right now, without prompting.
    ///
    /// Polling stops once trust is granted, so a later revocation goes unnoticed until someone asks again. The view
    /// model calls this before every start and about once a second while clicking. If trust turns out to be missing
    /// while monitoring is on, polling resumes so the banner reappears and hides again on its own.
    func refresh() {
        updateTrust()
        startPollingIfNeeded()
    }

    /// Opens the Accessibility pane of System Settings.
    func openAccessibilitySettings() {
        guard let url = Self.accessibilitySettingsURL else { return }
        openURL(url)
    }

    /// Suspends until the current polling task has finished. Lets tests wait deterministically.
    func waitForPollingToFinish() async {
        guard let task = pollingTask else { return }
        await task.value
    }

    private func updateTrust() {
        let trusted = checker.isTrusted
        // Avoid redundant observation notifications when the value has not changed.
        if trusted != isTrusted {
            isTrusted = trusted
        }
        if trusted {
            stopPolling()
        }
    }

    private func startPollingIfNeeded() {
        guard isMonitoring, !isTrusted, pollingTask == nil else { return }
        let interval = pollInterval
        // The task inherits main-actor isolation, so `updateTrust()` runs on the main actor.
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                // A thrown error here only means cancellation, which the loop condition handles.
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                self.updateTrust()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
