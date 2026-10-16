import os

@testable import AutoClicker

/// Thread-safe `PermissionChecking` stub that records how it is used.
final class MockPermissionChecker: PermissionChecking {
    private struct State {
        var isTrusted: Bool
        var isTrustedReadCount = 0
        var requestTrustCallCount = 0
        var grantAfterReads: Int?
    }

    private let state: OSAllocatedUnfairLock<State>

    init(isTrusted: Bool = false) {
        state = OSAllocatedUnfairLock(initialState: State(isTrusted: isTrusted))
    }

    var isTrusted: Bool {
        get {
            state.withLock { state in
                state.isTrustedReadCount += 1
                if let grantAfterReads = state.grantAfterReads, state.isTrustedReadCount >= grantAfterReads {
                    state.isTrusted = true
                }
                return state.isTrusted
            }
        }
        set {
            state.withLock { $0.isTrusted = newValue }
        }
    }

    func requestTrust() {
        state.withLock { $0.requestTrustCallCount += 1 }
    }

    /// Number of times `isTrusted` has been read.
    var isTrustedReadCount: Int {
        state.withLock { $0.isTrustedReadCount }
    }

    /// Number of times `requestTrust()` has been called.
    var requestTrustCallCount: Int {
        state.withLock { $0.requestTrustCallCount }
    }

    /// Makes the read with the given 1-based index, and every later read, report trust.
    ///
    /// Lets tests simulate a grant at an exact poll without racing the polling task.
    func grantTrust(atRead readIndex: Int) {
        state.withLock { $0.grantAfterReads = readIndex }
    }
}
