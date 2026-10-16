import CoreGraphics
import os

@testable import AutoClicker

/// `FailsafeChecking` stub whose decision tests can change mid-run, recording every evaluation.
///
/// The engine evaluates it on its click queue while tests flip `decision` from their own context, so all state is
/// guarded by a lock.
final class MockFailsafe: FailsafeChecking {
    /// One recorded call to `evaluate(cursor:target:)`.
    struct Evaluation: Sendable, Equatable {
        let cursor: CGPoint?
        let target: CGPoint
    }

    private struct State {
        var decision: FailsafeDecision
        var evaluations: [Evaluation] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(decision: FailsafeDecision = .proceed) {
        state = OSAllocatedUnfairLock(initialState: State(decision: decision))
    }

    /// The decision returned by every following evaluation.
    var decision: FailsafeDecision {
        get { state.withLock { $0.decision } }
        set { state.withLock { $0.decision = newValue } }
    }

    /// All recorded evaluations, oldest first.
    var evaluations: [Evaluation] {
        state.withLock { $0.evaluations }
    }

    func evaluate(cursor: CGPoint?, target: CGPoint) -> FailsafeDecision {
        state.withLock { state in
            state.evaluations.append(Evaluation(cursor: cursor, target: target))
            return state.decision
        }
    }
}
