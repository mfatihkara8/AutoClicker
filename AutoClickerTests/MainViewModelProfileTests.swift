import Carbon
import Foundation
import Testing

@testable import AutoClicker

@MainActor
struct MainViewModelProfileTests {
    private typealias Harness = MainViewModelHarness

    /// A harness whose store already holds `profiles`, with `activeProfileID` active.
    private func harness(
        profiles: [Profile], activeProfileID: UUID? = nil, configuration: ClickConfiguration = .default,
        countdownTick: Duration = .milliseconds(10)
    ) throws -> Harness {
        let harness = try Harness(countdownTick: countdownTick)
        harness.store.save(
            AppSettings(configuration: configuration, profiles: profiles, activeProfileID: activeProfileID))
        return harness
    }

    private static let fast = Harness.configuration(milliseconds: 50)
    private static let slow = Harness.configuration(milliseconds: 900, stopCondition: .afterClicks(3))

    // MARK: - Loading and saving

    @Test func initLoadsTheProfilesAndTheActiveProfile() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [work, game], activeProfileID: game.id, configuration: Self.slow)

        let viewModel = harness.viewModel

        #expect(viewModel.profiles == [work, game])
        #expect(viewModel.activeProfileID == game.id)
        #expect(viewModel.activeProfile == game)
        #expect(viewModel.isActiveProfileModified == false)
    }

    @Test func noProfileIsActiveByDefault() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        #expect(viewModel.profiles.isEmpty)
        #expect(viewModel.activeProfile == nil)
        #expect(viewModel.isActiveProfileModified == false)
        #expect(viewModel.canSaveNewProfile)
    }

    @Test func aDebouncedConfigurationSaveKeepsTheProfiles() async throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try harness(profiles: [work], activeProfileID: work.id)
        let viewModel = harness.viewModel
        let defaults = harness.defaults
        let writes = defaults.setCallCount

        viewModel.configuration = Self.slow

        #expect(await waitUntilOnMainActor { defaults.setCallCount > writes })
        let saved = harness.store.load()
        #expect(saved.configuration == Self.slow)
        #expect(saved.profiles == [work])
        #expect(saved.activeProfileID == work.id)
    }

    @Test func aShortcutChangeKeepsTheProfiles() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try Harness()
        let controlOptionK = Hotkey(
            keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), keyLabel: "K")
        harness.store.save(
            AppSettings(
                configuration: .default, toggleHotkey: controlOptionK, profiles: [work], activeProfileID: work.id))
        let viewModel = harness.viewModel

        viewModel.resetShortcut()

        let saved = harness.store.load()
        #expect(saved.toggleHotkey == .f6)
        #expect(saved.profiles == [work])
        #expect(saved.activeProfileID == work.id)
    }

    // MARK: - Save as new

    @Test func saveNewProfileSnapshotsTheConfigurationAndMakesItActive() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Self.fast

        let rejection = viewModel.saveNewProfile(named: "  Work  ")

        #expect(rejection == nil)
        let profile = try #require(viewModel.profiles.first)
        #expect(viewModel.profiles.count == 1)
        #expect(profile.name == "Work")
        #expect(profile.configuration == Self.fast)
        #expect(viewModel.activeProfileID == profile.id)
        #expect(viewModel.isActiveProfileModified == false)
        // Saved at once, not after the debounce.
        let saved = harness.store.load()
        #expect(saved.profiles == [profile])
        #expect(saved.activeProfileID == profile.id)
        #expect(saved.configuration == Self.fast)
    }

    @Test func saveNewProfileAppendsInOrder() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        viewModel.saveNewProfile(named: "First")
        viewModel.configuration = Self.slow
        viewModel.saveNewProfile(named: "Second")

        #expect(viewModel.profiles.map(\.name) == ["First", "Second"])
        #expect(viewModel.activeProfile?.name == "Second")
        #expect(viewModel.profiles[0].configuration == .default)
        #expect(viewModel.profiles[1].configuration == Self.slow)
    }

    @Test func saveNewProfileCutsALongName() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        viewModel.saveNewProfile(named: String(repeating: "a", count: Profile.maxNameLength + 10))

        #expect(viewModel.profiles.first?.name.count == Profile.maxNameLength)
    }

    @Test(arguments: [
        ("", Profile.NameRejection.empty),
        ("   ", .empty),
        ("work", .duplicate),
        (" WORK ", .duplicate),
    ])
    func saveNewProfileRejectsABadName(name: String, expected: Profile.NameRejection) throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try harness(profiles: [work])
        let viewModel = harness.viewModel
        let writes = harness.defaults.setCallCount

        #expect(viewModel.profileNameRejection(for: name) == expected)
        #expect(viewModel.saveNewProfile(named: name) == expected)

        #expect(viewModel.profiles == [work])
        #expect(viewModel.activeProfileID == nil)
        #expect(harness.defaults.setCallCount == writes)
    }

    @Test func saveNewProfileStopsAtTheLimit() throws {
        let profiles = (1...Profile.maxCount).map { Profile(name: "Profile \($0)", configuration: .default) }
        let harness = try harness(profiles: profiles)
        let viewModel = harness.viewModel

        #expect(viewModel.canSaveNewProfile == false)
        #expect(viewModel.saveNewProfile(named: "One more") == .tooManyProfiles)
        #expect(viewModel.profiles.count == Profile.maxCount)

        viewModel.deleteProfile(id: profiles[0].id)
        #expect(viewModel.canSaveNewProfile)
        #expect(viewModel.saveNewProfile(named: "One more") == nil)
        #expect(viewModel.profiles.count == Profile.maxCount)
    }

    // MARK: - Modified tracking

    @Test func editingTheConfigurationMarksTheActiveProfileModified() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel
        viewModel.configuration = Self.fast
        viewModel.saveNewProfile(named: "Work")

        viewModel.configuration.stopCondition = .afterClicks(10)
        #expect(viewModel.isActiveProfileModified)

        // Editing back to the snapshot is no longer a modification.
        viewModel.configuration.stopCondition = Self.fast.stopCondition
        #expect(viewModel.isActiveProfileModified == false)
    }

    // MARK: - Apply

    @Test func applyCopiesTheSnapshotAndMakesItActive() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [work, game], activeProfileID: work.id, configuration: Self.fast)
        let viewModel = harness.viewModel

        #expect(viewModel.applyProfile(id: game.id))

        #expect(viewModel.configuration == Self.slow)
        #expect(viewModel.activeProfileID == game.id)
        #expect(viewModel.isActiveProfileModified == false)
        // The profile is copied, not linked: editing the working configuration leaves it alone.
        viewModel.configuration.interval = ClickInterval(milliseconds: 5)
        #expect(viewModel.profiles[1] == game)
        #expect(viewModel.isActiveProfileModified)
    }

    @Test func applySavesImmediately() throws {
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [game])
        let viewModel = harness.viewModel

        viewModel.applyProfile(id: game.id)

        let saved = harness.store.load()
        #expect(saved.configuration == Self.slow)
        #expect(saved.activeProfileID == game.id)
    }

    @Test func applyRevertsAModifiedActiveProfile() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try harness(profiles: [work], activeProfileID: work.id, configuration: Self.slow)
        let viewModel = harness.viewModel
        #expect(viewModel.isActiveProfileModified)

        #expect(viewModel.applyProfile(id: work.id))

        #expect(viewModel.configuration == Self.fast)
        #expect(viewModel.isActiveProfileModified == false)
    }

    @Test func applyingAnUnknownProfileDoesNothing() throws {
        let harness = try Harness()
        let viewModel = harness.viewModel

        #expect(viewModel.applyProfile(id: UUID()) == false)
        #expect(viewModel.configuration == .default)
        #expect(harness.defaults.setCallCount == 0)
    }

    @Test func applyIsRejectedWhileClicking() async throws {
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [game], configuration: Harness.configuration())
        let viewModel = harness.viewModel
        viewModel.start()
        #expect(viewModel.isRunning)

        #expect(viewModel.canApplyProfile == false)
        #expect(viewModel.applyProfile(id: game.id) == false)

        #expect(viewModel.configuration == Harness.configuration())
        #expect(viewModel.activeProfileID == nil)
        viewModel.stop()
        #expect(await harness.waitForStop())
        #expect(viewModel.canApplyProfile)
    }

    @Test func applyIsRejectedDuringAPickLocationCountdown() throws {
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [game], countdownTick: .seconds(10))
        let viewModel = harness.viewModel
        viewModel.pickLocation()
        #expect(viewModel.isPickingLocation)

        #expect(viewModel.canApplyProfile == false)
        #expect(viewModel.applyProfile(id: game.id) == false)
        #expect(viewModel.configuration == .default)

        viewModel.cancelPickLocation()
        #expect(viewModel.applyProfile(id: game.id))
    }

    // MARK: - Save changes

    @Test func saveChangesOverwritesTheActiveSnapshot() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [work, game], activeProfileID: work.id, configuration: Self.fast)
        let viewModel = harness.viewModel
        viewModel.configuration.clickType = .right
        let edited = viewModel.configuration

        viewModel.saveChangesToActiveProfile()

        #expect(viewModel.profiles[0].configuration == edited)
        #expect(viewModel.profiles[0].id == work.id)
        #expect(viewModel.profiles[1] == game)
        #expect(viewModel.isActiveProfileModified == false)
        #expect(harness.store.load().profiles[0].configuration == edited)
    }

    @Test func saveChangesDoesNothingWithoutAModifiedActiveProfile() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try harness(profiles: [work], configuration: Self.slow)
        let viewModel = harness.viewModel
        let writes = harness.defaults.setCallCount

        // No profile is active.
        viewModel.saveChangesToActiveProfile()
        #expect(viewModel.profiles == [work])

        // Active but not modified.
        viewModel.applyProfile(id: work.id)
        let writesAfterApply = harness.defaults.setCallCount
        viewModel.saveChangesToActiveProfile()

        #expect(viewModel.profiles == [work])
        #expect(writesAfterApply == writes + 1)
        #expect(harness.defaults.setCallCount == writesAfterApply)
    }

    // MARK: - Rename

    @Test func renameKeepsTheIdentityAndTheActiveProfile() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try harness(profiles: [work], activeProfileID: work.id, configuration: Self.fast)
        let viewModel = harness.viewModel

        #expect(viewModel.renameProfile(id: work.id, to: "  Office ") == nil)

        #expect(viewModel.profiles.map(\.name) == ["Office"])
        #expect(viewModel.profiles[0].id == work.id)
        #expect(viewModel.activeProfile?.name == "Office")
        #expect(harness.store.load().profiles.map(\.name) == ["Office"])
    }

    @Test func renameMayChangeTheCaseOfItsOwnName() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try harness(profiles: [work])
        let viewModel = harness.viewModel

        #expect(viewModel.profileNameRejection(for: "WORK", renaming: work.id) == nil)
        #expect(viewModel.renameProfile(id: work.id, to: "WORK") == nil)

        #expect(viewModel.profiles.map(\.name) == ["WORK"])
    }

    @Test func renameRejectsAnotherProfilesNameAndAnEmptyName() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [work, game])
        let viewModel = harness.viewModel
        let writes = harness.defaults.setCallCount

        #expect(viewModel.renameProfile(id: work.id, to: "game") == .duplicate)
        #expect(viewModel.renameProfile(id: work.id, to: " ") == .empty)

        #expect(viewModel.profiles == [work, game])
        #expect(harness.defaults.setCallCount == writes)
    }

    @Test func renameIsAllowedAtTheLimit() throws {
        let profiles = (1...Profile.maxCount).map { Profile(name: "Profile \($0)", configuration: .default) }
        let harness = try harness(profiles: profiles)
        let viewModel = harness.viewModel

        #expect(viewModel.renameProfile(id: profiles[0].id, to: "Renamed") == nil)
        #expect(viewModel.profiles[0].name == "Renamed")
    }

    // MARK: - Delete

    @Test func deletingTheActiveProfileLeavesNoneActive() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [work, game], activeProfileID: work.id, configuration: Self.fast)
        let viewModel = harness.viewModel

        viewModel.deleteProfile(id: work.id)

        #expect(viewModel.profiles == [game])
        #expect(viewModel.activeProfileID == nil)
        // The working configuration stays.
        #expect(viewModel.configuration == Self.fast)
        let saved = harness.store.load()
        #expect(saved.profiles == [game])
        #expect(saved.activeProfileID == nil)
    }

    @Test func deletingAnotherProfileKeepsTheActiveOne() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let game = Profile(name: "Game", configuration: Self.slow)
        let harness = try harness(profiles: [work, game], activeProfileID: work.id, configuration: Self.fast)
        let viewModel = harness.viewModel

        viewModel.deleteProfile(id: game.id)

        #expect(viewModel.profiles == [work])
        #expect(viewModel.activeProfileID == work.id)
        #expect(harness.store.load().profiles == [work])
    }

    @Test func deletingAnUnknownProfileDoesNothing() throws {
        let work = Profile(name: "Work", configuration: Self.fast)
        let harness = try harness(profiles: [work])
        let viewModel = harness.viewModel
        let writes = harness.defaults.setCallCount

        viewModel.deleteProfile(id: UUID())

        #expect(viewModel.profiles == [work])
        #expect(harness.defaults.setCallCount == writes)
    }
}
