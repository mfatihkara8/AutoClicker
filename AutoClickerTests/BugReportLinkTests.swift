import Foundation
import Testing

@testable import AutoClicker

struct BugReportLinkTests {
    private func queryItems(_ url: URL?) throws -> [String: String] {
        let url = try #require(url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(components.queryItems)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func pointsAtTheNewIssueFormWithTheVersions() throws {
        let url = try #require(BugReportLink.url(appVersion: "1.0", macOSVersion: "26.1"))
        #expect(
            url.absoluteString
                == "https://github.com/mfatihkara8/AutoClicker/issues/new?template=bug_report.yml&app-version=1.0&macos-version=26.1"
        )
    }

    @Test func prefillsOnlyTheTemplateAndTheTwoVersions() throws {
        let items = try queryItems(BugReportLink.url(appVersion: "1.0 (1)", macOSVersion: "15.6.1"))
        #expect(items == ["template": "bug_report.yml", "app-version": "1.0 (1)", "macos-version": "15.6.1"])
    }

    @Test func percentEncodesSpacesAndParentheses() throws {
        let url = try #require(BugReportLink.url(appVersion: "1.0 (42)", macOSVersion: "26.1"))
        #expect(url.absoluteString.contains("app-version=1.0%20%2842%29&"))
    }

    @Test func encodesQuerySeparatorsSoAValueCannotAddItems() throws {
        let url = BugReportLink.url(appVersion: "1.0&title=x+y", macOSVersion: "26.1#frag")
        let items = try queryItems(url)
        #expect(items["app-version"] == "1.0&title=x+y")
        #expect(items["macos-version"] == "26.1#frag")
        #expect(items["title"] == nil)
        #expect(try #require(url).absoluteString.contains("1.0%26title%3Dx%2By"))
    }

    @Test func usesTheAppInfoVersionAndBuild() throws {
        let info = AppInfo(
            infoDictionary: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "7"],
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
        let items = try queryItems(BugReportLink.url(for: info))
        #expect(items["app-version"] == "0.1.0 (7)")
        #expect(items["macos-version"] == "26.0")
    }

    @Test func repositoryURLIsTheGitHubProject() {
        #expect(BugReportLink.repositoryURL?.absoluteString == "https://github.com/mfatihkara8/AutoClicker")
    }
}
