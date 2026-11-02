import Foundation

// The user-facing wording lives in `Features/` so that the profile model stays free of UI concerns.
extension Profile.NameRejection {
    /// A short, localized hint that tells the user why the name cannot be used.
    var displayText: String {
        switch self {
        case .empty:
            String(
                localized: "Enter a name.",
                comment: "Profile name hint: the name is empty after removing leading and trailing spaces.")
        case .duplicate:
            String(
                localized: "Another profile already has this name.",
                comment: "Profile name hint: the name matches another profile's name, ignoring case.")
        case .tooManyProfiles:
            String(
                localized: "You can save up to \(Profile.maxCount) profiles. Delete one to save a new one.",
                comment: "Profile name hint: the profile limit is reached; the argument is the limit, 50.")
        }
    }
}
