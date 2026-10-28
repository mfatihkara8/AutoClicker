import CoreGraphics
import Dispatch
import Testing

@testable import AutoClicker

struct MockEventPosterTests {
    @Test func recordsPostsInOrder() {
        let poster = MockEventPoster()
        poster.post(.left, at: CGPoint(x: 1, y: 2), modifiers: [])
        poster.post(.double, at: CGPoint(x: 3, y: 4), modifiers: [.shift, .command])
        #expect(
            poster.posts == [
                MockEventPoster.Post(type: .left, point: CGPoint(x: 1, y: 2)),
                MockEventPoster.Post(type: .double, point: CGPoint(x: 3, y: 4), modifiers: [.shift, .command]),
            ])
        #expect(poster.count == 2)
    }

    @Test func resetClearsRecordedPosts() {
        let poster = MockEventPoster()
        poster.post(.right, at: .zero, modifiers: [])
        poster.reset()
        #expect(poster.posts.isEmpty)
    }

    @Test func recordsConcurrentPostsWithoutLosingAny() {
        let poster = MockEventPoster()
        let postsPerWorker = 1_000
        let workers = 8
        DispatchQueue.concurrentPerform(iterations: workers) { _ in
            for _ in 0..<postsPerWorker {
                poster.post(.middle, at: .zero, modifiers: [])
            }
        }
        #expect(poster.count == postsPerWorker * workers)
    }

    @Test func isUsableThroughTheProtocol() {
        let poster = MockEventPoster()
        let posting: any EventPosting = poster
        for type in ClickType.allCases {
            posting.post(type, at: CGPoint(x: 10, y: 20), modifiers: .option)
        }
        #expect(poster.posts.map(\.type) == ClickType.allCases)
        #expect(poster.posts.allSatisfy { $0.modifiers == .option })
    }
}
