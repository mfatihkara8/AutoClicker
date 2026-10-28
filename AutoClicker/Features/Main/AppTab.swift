import SwiftUI

/// The tabs of the main window, in the order they are shown (SPEC §3.5).
enum AppTab: Hashable, CaseIterable {
    case main
    case click
    case shortcuts
    case about

    /// The tab's title in the tab bar or sidebar.
    var title: LocalizedStringKey {
        switch self {
        case .main: "Main"
        case .click: "Click"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    /// The SF Symbol shown next to the title.
    var systemImage: String {
        switch self {
        case .main: "play.circle"
        case .click: "cursorarrow.click"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }
}
