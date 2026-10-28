import Foundation

// The user-facing wording lives in `Features/` so that `Core/` stays free of UI concerns.
extension ClickType {
    /// The short, localized name shown in the click type picker.
    var displayName: String {
        switch self {
        case .left:
            String(localized: "Left", comment: "Click type: a primary-button click.")
        case .right:
            String(localized: "Right", comment: "Click type: a secondary-button click.")
        case .middle:
            String(localized: "Middle", comment: "Click type: a center-button click.")
        case .double:
            String(localized: "Double", comment: "Click type: a primary-button double click.")
        }
    }

    /// The localized name of one click of this type, such as "Left click", used in running-status text.
    var clickName: String {
        switch self {
        case .left:
            String(localized: "Left click", comment: "One primary-button click, as named in status text.")
        case .right:
            String(localized: "Right click", comment: "One secondary-button click, as named in status text.")
        case .middle:
            String(localized: "Middle click", comment: "One center-button click, as named in status text.")
        case .double:
            String(localized: "Double click", comment: "One primary-button double click, as named in status text.")
        }
    }
}
