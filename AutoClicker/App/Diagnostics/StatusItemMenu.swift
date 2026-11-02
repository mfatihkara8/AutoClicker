#if DIAGNOSTICS
    import AppKit

    /// Reads and chooses items of the `NSMenu` that SwiftUI builds for the menu bar extra, in process.
    ///
    /// The menu is reached through the status bar window that shows the extra's button: that window answers the
    /// `statusItem` key with its `NSStatusItem`, whose `menu` is SwiftUI's menu. This relies on AppKit internals and is
    /// only meant for the live check. The Accessibility API cannot be used for this part: while the menu is open, its
    /// tracking loop runs on the main thread, and an in-process Accessibility request for the menu then never returns.
    ///
    /// Call these while the menu is open (SwiftUI fills it when it opens), from a run loop timer that fires during the
    /// menu's tracking loop.
    @MainActor
    enum StatusItemMenu {
        /// One item of the Profiles submenu.
        struct MenuItem: Sendable, Codable, Equatable {
            var title: String
            /// Whether the item shows the checkmark (its state is on).
            var isChecked: Bool
            var isEnabled: Bool
        }

        enum Failure: Error, CustomStringConvertible {
            case notFound(String)

            var description: String {
                switch self {
                case .notFound(let what): "not found: \(what)"
                }
            }
        }

        /// The menu bar extra's menu: the menu of the first status item that has one.
        static func menu() -> NSMenu? {
            let key = "statusItem"
            for window in NSApplication.shared.windows where window.responds(to: NSSelectorFromString(key)) {
                if let menu = (window.value(forKey: key) as? NSStatusItem)?.menu {
                    return menu
                }
            }
            return nil
        }

        /// The items of the Profiles submenu, as the open menu shows them.
        static func profileItems() throws -> [MenuItem] {
            try profilesSubmenu().items.filter { !$0.isSeparatorItem }.map { item in
                MenuItem(title: item.title, isChecked: item.state == .on, isEnabled: item.isEnabled)
            }
        }

        /// Chooses the item named `name` in the Profiles submenu, as a click on it does, and closes the menu.
        static func chooseProfileItem(named name: String) throws {
            let submenu = try profilesSubmenu()
            guard let index = submenu.items.firstIndex(where: { $0.title == name }) else {
                throw Failure.notFound("item \(name) in the Profiles submenu")
            }
            submenu.performActionForItem(at: index)
            close()
        }

        /// Ends the menu's tracking loop, which closes it.
        static func close() {
            menu()?.cancelTracking()
        }

        private static func profilesSubmenu() throws -> NSMenu {
            guard let menu = menu() else {
                throw Failure.notFound("the menu bar extra's menu")
            }
            guard let submenu = menu.items.first(where: { $0.title == "Profiles" })?.submenu else {
                throw Failure.notFound("a Profiles submenu (menu items: \(menu.items.map(\.title)))")
            }
            return submenu
        }
    }
#endif
