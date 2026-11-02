import Foundation

/// A named snapshot of a click configuration that the user can apply later (SPEC §7.3, ADR-013).
///
/// The start/stop shortcut is global and not part of a profile. Applying a profile copies `configuration` into the
/// working configuration; editing the working configuration never changes a profile until the user saves.
///
/// ## Names
/// A stored name is normalized (see `normalizedName(_:)`), 1 to `maxNameLength` characters long and unique among the
/// profiles ignoring case. `nameRejection(for:among:renaming:)` checks a candidate before a save or rename, and
/// `repaired(_:)` restores these rules for profiles loaded from storage.
struct Profile: Sendable, Codable, Equatable, Identifiable {
    /// The longest name, in characters, after trimming.
    static let maxNameLength = 40
    /// The most profiles that can be stored.
    static let maxCount = 50
    /// The name given to a stored profile whose name is empty after trimming.
    static let fallbackName = "Profile"

    /// Why a candidate name was rejected by `nameRejection(for:among:renaming:)`.
    enum NameRejection: Sendable, Equatable {
        /// The name is empty after trimming.
        case empty
        /// Another profile already has this name, ignoring case.
        case duplicate
        /// `maxCount` profiles are already stored, so no new profile can be saved.
        case tooManyProfiles
    }

    /// The profile's identity. It never changes, even on rename, so the active profile survives a rename.
    let id: UUID
    /// The display name, normalized and unique ignoring case.
    var name: String
    /// The click settings this profile applies.
    var configuration: ClickConfiguration

    init(id: UUID = UUID(), name: String, configuration: ClickConfiguration) {
        self.id = id
        self.name = name
        self.configuration = configuration
    }

    // Explicit keys: profiles are part of the persisted settings schema (version 4), so renaming a property must not
    // silently change the stored JSON.
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case configuration
    }

    // MARK: - Name rules

    /// Returns `candidate` trimmed of whitespace and newlines and cut to `maxNameLength` characters. Whitespace left
    /// at the end by the cut is trimmed too. The result may be empty.
    static func normalizedName(_ candidate: String) -> String {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns why `candidate` cannot be used as a profile name, or `nil` when it can.
    ///
    /// The candidate is normalized first, so callers store `normalizedName(candidate)` once this returns `nil`.
    ///
    /// - Parameters:
    ///   - candidate: The name as typed.
    ///   - profiles: The stored profiles.
    ///   - id: The profile being renamed, or `nil` when `candidate` names a new profile. A renamed profile may keep
    ///     its own name in another case, and renaming never hits `maxCount`.
    static func nameRejection(
        for candidate: String, among profiles: [Profile], renaming id: UUID? = nil
    ) -> NameRejection? {
        if id == nil, profiles.count >= maxCount {
            return .tooManyProfiles
        }
        let name = normalizedName(candidate)
        if name.isEmpty {
            return .empty
        }
        let key = comparisonKey(name)
        if profiles.contains(where: { $0.id != id && comparisonKey(normalizedName($0.name)) == key }) {
            return .duplicate
        }
        return nil
    }

    /// Returns `profiles` with the name rules restored, for profiles loaded from storage.
    ///
    /// Keeps the order and the first `maxCount` profiles. Each name is normalized, an empty name becomes
    /// `fallbackName`, and a name already used by an earlier profile (ignoring case) gets the first free suffix
    /// " 2", " 3", …, cutting the name so it still fits `maxNameLength`. A repeated `id` gets a fresh one, so the first
    /// profile with an id keeps it.
    static func repaired(_ profiles: [Profile]) -> [Profile] {
        var usedNames: Set<String> = []
        var usedIDs: Set<UUID> = []
        return profiles.prefix(maxCount).map { profile in
            var name = normalizedName(profile.name)
            if name.isEmpty {
                name = fallbackName
            }
            if usedNames.contains(comparisonKey(name)) {
                name = uniqueName(base: name, avoiding: usedNames)
            }
            usedNames.insert(comparisonKey(name))
            let id = usedIDs.contains(profile.id) ? UUID() : profile.id
            usedIDs.insert(id)
            return Profile(id: id, name: name, configuration: profile.configuration)
        }
    }

    /// The first "base N" (N ≥ 2) whose key is not in `usedNames`, with `base` cut so the result fits.
    private static func uniqueName(base: String, avoiding usedNames: Set<String>) -> String {
        var number = 2
        while true {
            let suffix = " \(number)"
            let cut = String(base.prefix(maxNameLength - suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = cut + suffix
            if !usedNames.contains(comparisonKey(candidate)) {
                return candidate
            }
            number += 1
        }
    }

    /// The form two names are compared in: equal keys mean the names differ at most in case. Locale-independent, so
    /// the rule does not change with the user's language.
    private static func comparisonKey(_ name: String) -> String {
        name.folding(options: .caseInsensitive, locale: nil)
    }
}
