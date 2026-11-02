#if DIAGNOSTICS
    import Foundation

    /// A throwaway `UserDefaults` suite for a diagnostics launch, so the user's real settings are never read or
    /// written.
    ///
    /// The suite name is an absolute path in a temporary folder, as in `TestDefaultsSuite`: a plain name would leave a
    /// plist in `~/Library/Preferences`, which `cfprefsd` can write back after it is deleted.
    struct DiagnosticsDefaults {
        let suiteName: String
        let defaults: UserDefaults

        /// Creates an empty suite with a unique name, or returns `nil` when `UserDefaults` refuses the name.
        init?() {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
                "AutoClickerDiagnostics.defaults", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let suiteName = directory.appendingPathComponent("Diagnostics.\(UUID().uuidString)").path
            guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
            defaults.removePersistentDomain(forName: suiteName)
            self.suiteName = suiteName
            self.defaults = defaults
        }

        /// Removes the suite's persistent domain and its plist.
        static func remove(suiteName: String) {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(atPath: suiteName + ".plist")
        }
    }
#endif
