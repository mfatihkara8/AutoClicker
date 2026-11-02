import CoreGraphics
import Testing

@testable import AutoClicker

/// Click sequences in the view model (T-1201): Add Point and the target memory.
@MainActor
struct MainViewModelSequenceTests {
    private typealias Harness = MainViewModelHarness

    private nonisolated static let first = ClickPoint(point: CGPoint(x: 10, y: 20), delayMilliseconds: 100)
    /// Where `Harness.Environment.pickCursor` puts the cursor by default.
    private nonisolated static let pickedPoint = CGPoint(x: 321, y: 654)

    private static func sequenceConfiguration(
        _ points: [ClickPoint], interval: ClickInterval = ClickInterval(milliseconds: 250)
    ) -> ClickConfiguration {
        ClickConfiguration(clickType: .left, interval: interval, target: .sequence(points), stopCondition: .never)
    }

    // MARK: - Add Point (T-1201)

    @Test func addPointAppendsTheCursorWithTheIntervalAsDelay() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel
        viewModel.configuration = Self.sequenceConfiguration([Self.first])
        #expect(viewModel.canAddSequencePoint)

        viewModel.addSequencePoint()

        #expect(viewModel.addSequencePointCountdown == 3)
        #expect(viewModel.fixedTargetPickCountdown == nil)
        #expect(viewModel.pickLocationPurpose == .sequencePoint)
        #expect(viewModel.canAddSequencePoint == false)
        #expect(await waitUntilOnMainActor { !viewModel.isPickingLocation })

        #expect(viewModel.pickLocationPurpose == nil)
        #expect(viewModel.addSequencePointCountdown == nil)
        #expect(
            viewModel.configuration.target
                == .sequence([Self.first, ClickPoint(point: Self.pickedPoint, delayMilliseconds: 250)]))
    }

    @Test func addPointClampsTheDelayToTheSupportedRange() async throws {
        let harness = try Harness(countdownTick: .milliseconds(5))
        let viewModel = harness.viewModel
        viewModel.configuration = Self.sequenceConfiguration([], interval: ClickInterval(hours: 30))

        viewModel.addSequencePoint()
        #expect(await waitUntilOnMainActor { !viewModel.isPickingLocation })

        let expected = ClickPoint(point: Self.pickedPoint, delayMilliseconds: ClickPoint.delayRange.upperBound)
        #expect(viewModel.configuration.target == .sequence([expected]))
    }

    @Test(arguments: [ClickTarget.currentCursor, .fixed(CGPoint(x: 1, y: 2))])
    func addPointNeedsASequenceTarget(target: ClickTarget) throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration.target = target

        #expect(viewModel.canAddSequencePoint == false)
        viewModel.addSequencePoint()

        #expect(viewModel.isPickingLocation == false)
    }

    @Test func addPointIsIgnoredWhenTheSequenceIsFull() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        let full = Array(repeating: Self.first, count: ClickTarget.maxSequencePoints)
        viewModel.configuration = Self.sequenceConfiguration(full)

        #expect(viewModel.canAddSequencePoint == false)
        viewModel.addSequencePoint()

        #expect(viewModel.isPickingLocation == false)
    }

    @Test func addPointIsIgnoredWhileRunning() async throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Self.sequenceConfiguration([Self.first])
        viewModel.start()

        #expect(viewModel.canAddSequencePoint == false)
        viewModel.addSequencePoint()

        #expect(viewModel.isPickingLocation == false)
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    @Test func cancelledAddPointLeavesTheSequenceUnchanged() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel
        viewModel.configuration = Self.sequenceConfiguration([Self.first])

        viewModel.addSequencePoint()
        viewModel.cancelAddSequencePoint()

        #expect(viewModel.isPickingLocation == false)
        #expect(viewModel.pickLocationPurpose == nil)
        try await Task.sleep(for: .milliseconds(80))
        #expect(viewModel.configuration.target == .sequence([Self.first]))
    }

    @Test func cancelAddPointKeepsAFixedPickRunning() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel

        viewModel.pickLocation()
        #expect(viewModel.fixedTargetPickCountdown == 3)
        #expect(viewModel.addSequencePointCountdown == nil)
        viewModel.cancelAddSequencePoint()

        #expect(viewModel.isPickingLocation)
        #expect(await waitUntilOnMainActor { !viewModel.isPickingLocation })
        #expect(viewModel.configuration.target == .fixed(Self.pickedPoint))
    }

    @Test func addPointIsDroppedWhenTheTargetIsNoLongerASequence() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel
        viewModel.configuration = Self.sequenceConfiguration([Self.first])

        viewModel.addSequencePoint()
        // A profile applied from the menu bar, for example.
        viewModel.configuration.target = .fixed(CGPoint(x: 5, y: 5))
        #expect(await waitUntilOnMainActor { !viewModel.isPickingLocation })

        #expect(viewModel.configuration.target == .fixed(CGPoint(x: 5, y: 5)))
    }

    @Test func addPointWithoutACursorLeavesTheSequenceUnchanged() async throws {
        let harness = try Harness(countdownTick: .milliseconds(5))
        harness.environment.pickCursor = nil
        let viewModel = harness.viewModel
        viewModel.configuration = Self.sequenceConfiguration([Self.first])

        viewModel.addSequencePoint()
        #expect(await waitUntilOnMainActor { !viewModel.isPickingLocation })

        #expect(viewModel.configuration.target == .sequence([Self.first]))
    }

    @Test func startCancelsAnAddPointInProgress() async throws {
        let harness = try Harness(countdownTick: .milliseconds(10))
        let viewModel = harness.viewModel
        viewModel.configuration = Self.sequenceConfiguration([Self.first])
        viewModel.addSequencePoint()

        viewModel.start()

        #expect(viewModel.isPickingLocation == false)
        #expect(viewModel.pickLocationPurpose == nil)
        try await Task.sleep(for: .milliseconds(60))
        #expect(viewModel.configuration.target == .sequence([Self.first]))
        viewModel.stop()
        #expect(await harness.waitForStop())
    }

    // MARK: - Target memory (T-1201)

    @Test func theMemoryStartsFromTheSavedTarget() throws {
        let harness = try Harness()
        harness.store.save(AppSettings(configuration: Self.sequenceConfiguration([Self.first])))

        let memory = harness.viewModel.targetMemory

        #expect(memory.sequencePoints == [Self.first])
        #expect(memory.fixedPoint == .zero)
    }

    @Test func theMemoryKeepsEachModesLastValues() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        viewModel.configuration.target = .fixed(CGPoint(x: 7, y: 8))
        viewModel.configuration.target = .sequence([Self.first])
        viewModel.configuration.target = .currentCursor

        #expect(
            viewModel.targetMemory == ClickTargetMemory(fixedPoint: CGPoint(x: 7, y: 8), sequencePoints: [Self.first]))
    }

    @Test func switchingKindsThroughTheEditorBringsTheValuesBack() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration.target = .fixed(CGPoint(x: 7, y: 8))

        // What the Target section's picker does.
        func select(_ kind: ClickTargetEditor.Kind) {
            var editor = ClickTargetEditor(target: viewModel.configuration.target, memory: viewModel.targetMemory)
            editor.kind = kind
            viewModel.configuration.target = editor.target
        }

        select(.sequence)
        viewModel.configuration.target = .sequence([Self.first])
        select(.currentCursor)
        select(.fixed)
        #expect(viewModel.configuration.target == .fixed(CGPoint(x: 7, y: 8)))
        select(.sequence)
        #expect(viewModel.configuration.target == .sequence([Self.first]))
    }
}
