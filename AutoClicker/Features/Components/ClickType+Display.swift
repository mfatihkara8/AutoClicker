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
}
