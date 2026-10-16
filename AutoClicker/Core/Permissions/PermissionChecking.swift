/// Reads and requests the Accessibility trust the app needs to post synthetic clicks.
///
/// The engine and `PermissionManager` only see this protocol, so tests can swap in a mock
/// and never touch the real TCC database or show a system prompt.
protocol PermissionChecking: Sendable {
    /// Whether the process is currently trusted for Accessibility.
    ///
    /// Reading this never shows a system prompt, so it is safe to poll.
    var isTrusted: Bool { get }

    /// Asks the system to show its Accessibility prompt.
    ///
    /// Call this only in response to an explicit user action.
    func requestTrust()
}
