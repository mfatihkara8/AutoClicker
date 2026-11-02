#if DIAGNOSTICS
    import os

    /// A `PermissionChecking` whose trust state the diagnostics driver sets, so it can show the permission banner or
    /// start a run without the real Accessibility grant. It never shows the system prompt.
    ///
    /// Only used together with `NoOpEventPoster`: a run started on fake trust must not post anything.
    final class DiagnosticsPermissionChecker: PermissionChecking {
        private let trusted: OSAllocatedUnfairLock<Bool>

        init(isTrusted: Bool) {
            trusted = OSAllocatedUnfairLock(initialState: isTrusted)
        }

        var isTrusted: Bool {
            trusted.withLock { $0 }
        }

        func requestTrust() {}

        /// Changes what `isTrusted` reports from now on.
        func setTrusted(_ isTrusted: Bool) {
            trusted.withLock { $0 = isTrusted }
        }
    }
#endif
