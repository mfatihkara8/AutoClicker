import Foundation

/// The app's name, version and build as read from its bundle, plus the macOS version it runs on.
///
/// A plain value built from an info dictionary, so the About tab and the bug report link can be tested without a real
/// bundle.
struct AppInfo: Equatable, Sendable {
    /// The display name, such as "AutoClicker".
    let name: String
    /// The marketing version (`CFBundleShortVersionString`), such as "1.0".
    let version: String
    /// The build number (`CFBundleVersion`), such as "1".
    let build: String
    /// The macOS version, such as "26.1" or "15.6.1".
    let macOSVersion: String

    /// The version and build together, such as "1.0 (1)", as shown in About and sent with bug reports.
    var versionAndBuild: String {
        "\(version) (\(build))"
    }

    /// Reads the app's info from an info dictionary, falling back to placeholders for missing keys.
    init(infoDictionary: [String: Any], operatingSystemVersion: OperatingSystemVersion) {
        let fallbackName = String(localized: "AutoClicker", comment: "The app's name, used if the bundle lacks one.")
        name =
            infoDictionary["CFBundleDisplayName"] as? String
            ?? infoDictionary["CFBundleName"] as? String
            ?? fallbackName
        // "?" rather than an empty string, so a bug report still shows that the value was missing.
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? "?"
        build = infoDictionary["CFBundleVersion"] as? String ?? "?"
        macOSVersion = Self.versionString(operatingSystemVersion)
    }

    /// The running app's info.
    static func current(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) -> AppInfo {
        AppInfo(
            infoDictionary: bundle.infoDictionary ?? [:],
            operatingSystemVersion: processInfo.operatingSystemVersion)
    }

    /// "26.1" for 26.1.0 and "15.6.1" for 15.6.1: the patch is left out when it is zero, as macOS itself does.
    static func versionString(_ version: OperatingSystemVersion) -> String {
        let base = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion == 0 ? base : "\(base).\(version.patchVersion)"
    }
}
