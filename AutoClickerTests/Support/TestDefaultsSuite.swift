import Foundation

/// Names and removes throwaway `UserDefaults` suites for tests.
///
/// A plain suite name such as `AutoClickerTests.<UUID>` leaves an empty plist in `~/Library/Preferences` even after
/// `removePersistentDomain(forName:)`, and deleting that file races `cfprefsd`, which writes it back later. A suite name
/// that is an absolute path keeps the plist in a temporary folder instead, so nothing is left in the user's
/// preferences whichever way the race goes.
enum TestDefaultsSuite {
    /// The folder that holds every test suite's plist.
    static let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "AutoClickerTests.defaults", isDirectory: true)

    /// Returns a new, unique suite name inside `directory`, creating the folder when needed.
    static func makeName(prefix: String) -> String {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(prefix).\(UUID().uuidString)").path
    }

    /// Removes the suite's persistent domain and its plist.
    static func remove(_ suiteName: String) {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(atPath: suiteName + ".plist")
    }
}
