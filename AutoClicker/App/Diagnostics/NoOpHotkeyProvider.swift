#if DIAGNOSTICS
    /// A `HotkeyProviding` that accepts every registration without telling the system, so a snapshot run neither takes
    /// F6 or Esc away from other apps nor shows a "shortcut in use" warning when the installed app already owns F6.
    @MainActor
    final class NoOpHotkeyProvider: HotkeyProviding {
        private var registered: Set<Hotkey> = []

        func register(_ hotkey: Hotkey, handler: @escaping @MainActor () -> Void) throws {
            registered.insert(hotkey)
        }

        func unregister(_ hotkey: Hotkey) {
            registered.remove(hotkey)
        }

        func unregisterAll() {
            registered.removeAll()
        }

        func isRegistered(_ hotkey: Hotkey) -> Bool {
            registered.contains(hotkey)
        }
    }
#endif
