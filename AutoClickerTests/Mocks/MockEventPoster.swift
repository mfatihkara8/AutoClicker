import CoreGraphics
import os

@testable import AutoClicker

/// Records every click instead of posting it, so engine tests never touch the real event system.
///
/// The engine posts from its serial background queue while tests read from their own context, so the recording is
/// guarded by a lock.
final class MockEventPoster: EventPosting {
    /// One recorded call to `post(_:at:modifiers:)`.
    struct Post: Sendable, Equatable {
        let type: ClickType
        let point: CGPoint
        let modifiers: ClickModifiers

        init(type: ClickType, point: CGPoint, modifiers: ClickModifiers = []) {
            self.type = type
            self.point = point
            self.modifiers = modifiers
        }
    }

    private let recorded = OSAllocatedUnfairLock<[Post]>(initialState: [])

    /// All recorded posts, oldest first.
    var posts: [Post] {
        recorded.withLock { $0 }
    }

    /// The number of recorded posts.
    var count: Int {
        recorded.withLock { $0.count }
    }

    func post(_ type: ClickType, at point: CGPoint, modifiers: ClickModifiers) {
        recorded.withLock { $0.append(Post(type: type, point: point, modifiers: modifiers)) }
    }

    /// Forgets every recorded post.
    func reset() {
        recorded.withLock { $0.removeAll() }
    }
}
