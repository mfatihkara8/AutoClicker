import ApplicationServices

/// `PermissionChecking` backed by the Accessibility (AX) trust APIs.
///
/// This is the only type that calls `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions`.
struct AccessibilityPermissionChecker: PermissionChecking {
    /// Uses `AXIsProcessTrusted()`, which never prompts, so polling it is side-effect free.
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system Accessibility prompt via `AXIsProcessTrustedWithOptions`.
    ///
    /// The prompt also adds the app to the Accessibility list in System Settings, which saves the
    /// user from adding it by hand.
    func requestTrust() {
        let options = [Self.promptOptionKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// The value of `kAXTrustedCheckOptionPrompt`. The SDK exposes that constant as a mutable
    /// global, which Swift 6 rejects as not concurrency-safe, so its documented string value is used.
    private static let promptOptionKey = "AXTrustedCheckOptionPrompt"
}
