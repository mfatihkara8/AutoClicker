import Foundation

/// The wording around the active profile on the Main and Profiles tabs, such as "Profile: Work (modified)".
///
/// A plain value so the wording can be unit tested without building a view.
struct ProfilePresentation: Equatable {
    /// The active profile's name.
    let name: String
    /// Whether the working configuration differs from the profile's snapshot.
    let isModified: Bool

    /// The Main tab's line above the settings summary: "Profile: Name" or "Profile: Name (modified)".
    var statusText: String {
        if isModified {
            return String(
                localized: "Profile: \(name) (modified)",
                comment: """
                    Main tab: the active profile, whose settings were changed since it was applied or saved; the \
                    argument is its name.
                    """)
        }
        return String(
            localized: "Profile: \(name)",
            comment: "Main tab: the active profile, applied or saved last; the argument is its name.")
    }

    /// The title of the button that overwrites the active profile with the current settings.
    var saveChangesTitle: String {
        String(
            localized: "Save Changes to “\(name)”",
            comment: "Profiles tab: the button that stores the current settings in the active profile, named here.")
    }
}
