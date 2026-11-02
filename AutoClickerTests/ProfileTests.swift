import CoreGraphics
import Foundation
import Testing

@testable import AutoClicker

struct ProfileTests {
    private static func profile(_ name: String, id: UUID = UUID()) -> Profile {
        Profile(id: id, name: name, configuration: .default)
    }

    private static func profiles(count: Int) -> [Profile] {
        (1...count).map { profile("Profile \($0)") }
    }

    @Test func limitsMatchTheSpec() {
        #expect(Profile.maxNameLength == 40)
        #expect(Profile.maxCount == 50)
        #expect(Profile.fallbackName == "Profile")
    }

    // MARK: - Coding

    @Test func encodesIdNameAndConfiguration() throws {
        let id = try #require(UUID(uuidString: "6F1C1B5E-2D7A-4C3B-9E8F-0123456789AB"))
        let data = try JSONEncoder().encode(Profile(id: id, name: "Game", configuration: .default))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["id", "name", "configuration"])
        #expect(object["id"] as? String == "6F1C1B5E-2D7A-4C3B-9E8F-0123456789AB")
        #expect(object["name"] as? String == "Game")
        let configuration = try #require(object["configuration"] as? [String: Any])
        #expect(configuration["positionOffset"] as? Int == 0)
    }

    @Test func codableRoundTrip() throws {
        var configuration = ClickConfiguration.default
        configuration.target = .sequence([ClickPoint(point: CGPoint(x: 1, y: 2), delayMilliseconds: 30)])
        configuration.positionOffset = 15
        let profile = Profile(name: "Farm", configuration: configuration)
        let data = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(Profile.self, from: data) == profile)
    }

    // MARK: - Normalizing

    @Test(arguments: [
        ("Game", "Game"),
        ("  Game  ", "Game"),
        ("\n\tGame mode\n", "Game mode"),
        ("   ", ""),
        ("", ""),
    ])
    func normalizingTrimsWhitespaceAndNewlines(candidate: String, expected: String) {
        #expect(Profile.normalizedName(candidate) == expected)
    }

    @Test func normalizingCutsToFortyCharacters() {
        let name = Profile.normalizedName(String(repeating: "a", count: 45))
        #expect(name == String(repeating: "a", count: 40))
    }

    @Test func normalizingCountsCharactersNotBytes() {
        let name = Profile.normalizedName(String(repeating: "ş", count: 41))
        #expect(name.count == 40)
    }

    @Test func normalizingTrimsWhitespaceLeftByTheCut() {
        let candidate = String(repeating: "a", count: 39) + "  b"
        #expect(Profile.normalizedName(candidate) == String(repeating: "a", count: 39))
    }

    // MARK: - Validation

    @Test func acceptsANewUniqueName() {
        #expect(Profile.nameRejection(for: "Work", among: [Self.profile("Game")]) == nil)
        #expect(Profile.nameRejection(for: "Work", among: []) == nil)
    }

    @Test(arguments: ["", "   ", "\n"])
    func rejectsAnEmptyName(candidate: String) {
        #expect(Profile.nameRejection(for: candidate, among: []) == .empty)
    }

    @Test(arguments: ["Game", "game", "GAME", "  gAmE  "])
    func rejectsADuplicateIgnoringCase(candidate: String) {
        #expect(Profile.nameRejection(for: candidate, among: [Self.profile("Game")]) == .duplicate)
    }

    @Test func comparesTheNormalizedName() {
        let long = String(repeating: "a", count: 40)
        #expect(Profile.nameRejection(for: long + "zzz", among: [Self.profile(long)]) == .duplicate)
    }

    @Test func rejectsANewProfileBeyondTheLimit() {
        #expect(Profile.nameRejection(for: "New", among: Self.profiles(count: 50)) == .tooManyProfiles)
        #expect(Profile.nameRejection(for: "New", among: Self.profiles(count: 49)) == nil)
    }

    @Test func renamingMayChangeTheCaseOfItsOwnName() {
        let game = Self.profile("Game")
        #expect(Profile.nameRejection(for: "GAME", among: [game], renaming: game.id) == nil)
    }

    @Test func renamingStillRejectsAnotherProfilesName() {
        let game = Self.profile("Game")
        let work = Self.profile("Work")
        #expect(Profile.nameRejection(for: "work", among: [game, work], renaming: game.id) == .duplicate)
        #expect(Profile.nameRejection(for: " ", among: [game, work], renaming: game.id) == .empty)
    }

    @Test func renamingIsAllowedAtTheLimit() {
        let profiles = Self.profiles(count: 50)
        #expect(Profile.nameRejection(for: "Renamed", among: profiles, renaming: profiles[0].id) == nil)
    }

    // MARK: - Repair

    @Test func repairKeepsValidProfilesUnchanged() {
        let profiles = [Self.profile("Game"), Self.profile("Work")]
        #expect(Profile.repaired(profiles) == profiles)
    }

    @Test func repairTrimsAndCutsNames() {
        let repaired = Profile.repaired([
            Self.profile("  Game \n"),
            Self.profile(String(repeating: "x", count: 41)),
        ])
        #expect(repaired.map(\.name) == ["Game", String(repeating: "x", count: 40)])
    }

    @Test func repairNamesEmptyProfiles() {
        let repaired = Profile.repaired([Self.profile(""), Self.profile("  "), Self.profile("Profile")])
        #expect(repaired.map(\.name) == ["Profile", "Profile 2", "Profile 3"])
    }

    @Test func repairNumbersDuplicatesIgnoringCaseInOrder() {
        let repaired = Profile.repaired([
            Self.profile("Game"), Self.profile("game"), Self.profile("Work"), Self.profile("GAME"),
        ])
        #expect(repaired.map(\.name) == ["Game", "game 2", "Work", "GAME 3"])
    }

    @Test func repairSkipsSuffixesAlreadyTaken() {
        let repaired = Profile.repaired([Self.profile("Game 2"), Self.profile("Game"), Self.profile("game")])
        #expect(repaired.map(\.name) == ["Game 2", "Game", "game 3"])
    }

    @Test func repairCutsALongNameToFitTheSuffix() {
        let long = String(repeating: "a", count: 40)
        let repaired = Profile.repaired([Self.profile(long), Self.profile(long)])
        #expect(repaired[1].name == String(repeating: "a", count: 38) + " 2")
        #expect(repaired.allSatisfy { $0.name.count <= Profile.maxNameLength })
    }

    @Test func repairKeepsIdsConfigurationsAndOrder() {
        var configuration = ClickConfiguration.default
        configuration.clickType = .right
        let first = Profile(name: "a", configuration: configuration)
        let second = Profile(name: "A", configuration: .default)
        let repaired = Profile.repaired([first, second])
        #expect(repaired.map(\.id) == [first.id, second.id])
        #expect(repaired.map(\.configuration) == [configuration, .default])
    }

    @Test func repairDropsProfilesBeyondFifty() {
        let profiles = Self.profiles(count: 53)
        let repaired = Profile.repaired(profiles)
        #expect(repaired.count == 50)
        #expect(repaired == Array(profiles.prefix(50)))
    }

    @Test func repairGivesARepeatedIdAFreshOne() {
        let id = UUID()
        let repaired = Profile.repaired([Self.profile("One", id: id), Self.profile("Two", id: id)])
        #expect(repaired[0].id == id)
        #expect(repaired[1].id != id)
        #expect(repaired.map(\.name) == ["One", "Two"])
    }

    @Test func repairedNamesPassValidationAgainstEachOther() {
        let repaired = Profile.repaired([
            Self.profile(" "), Self.profile("Game"), Self.profile("GAME"),
            Self.profile(String(repeating: "g", count: 60)),
        ])
        for profile in repaired {
            #expect(Profile.nameRejection(for: profile.name, among: repaired, renaming: profile.id) == nil)
            #expect(Profile.normalizedName(profile.name) == profile.name)
        }
    }
}
