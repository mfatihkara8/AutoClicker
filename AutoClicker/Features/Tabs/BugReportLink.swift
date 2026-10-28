import Foundation

/// Builds the link that opens the repository's bug report issue form, prefilled with the app and macOS versions.
///
/// Only the two versions are prefilled (SPEC §3.5): nothing else about the user's machine or settings leaves the app.
/// The query keys match the input ids in `.github/ISSUE_TEMPLATE/bug_report.yml`.
enum BugReportLink {
    /// The public repository the About tab links to.
    static let repositoryURLString = "https://github.com/mfatihkara8/AutoClicker"

    /// The issue form's file name, as GitHub expects it in the `template` query item.
    static let templateName = "bug_report.yml"

    /// The repository URL, or `nil` only if the constant above were ever malformed.
    static var repositoryURL: URL? {
        URL(string: repositoryURLString)
    }

    /// Unreserved characters (RFC 3986) only, so spaces, parentheses, `+` and `&` in a version are always encoded and
    /// can never be read as another query item or as a space.
    private static let allowedValueCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// The new-issue URL with the bug report template selected and the versions prefilled.
    static func url(appVersion: String, macOSVersion: String) -> URL? {
        let items = [
            ("template", templateName),
            ("app-version", appVersion),
            ("macos-version", macOSVersion),
        ]
        let query =
            items
            .map { key, value in "\(key)=\(encode(value))" }
            .joined(separator: "&")
        return URL(string: "\(repositoryURLString)/issues/new?\(query)")
    }

    /// The new-issue URL for the running app.
    static func url(for info: AppInfo) -> URL? {
        url(appVersion: info.versionAndBuild, macOSVersion: info.macOSVersion)
    }

    private static func encode(_ value: String) -> String {
        // Only fails for strings that are not valid Unicode, which a Swift `String` always is.
        value.addingPercentEncoding(withAllowedCharacters: allowedValueCharacters) ?? ""
    }
}
