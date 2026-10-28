import Foundation
import Testing

@testable import AutoClicker

struct AppInfoTests {
    private static let macOS26 = OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0)

    @Test func readsNameVersionAndBuild() {
        let info = AppInfo(
            infoDictionary: [
                "CFBundleName": "AutoClicker",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
            ],
            operatingSystemVersion: Self.macOS26)
        #expect(info.name == "AutoClicker")
        #expect(info.versionAndBuild == "1.0 (1)")
        #expect(info.macOSVersion == "26.1")
    }

    @Test func prefersTheDisplayName() {
        let info = AppInfo(
            infoDictionary: ["CFBundleName": "AutoClicker", "CFBundleDisplayName": "Auto Clicker"],
            operatingSystemVersion: Self.macOS26)
        #expect(info.name == "Auto Clicker")
    }

    @Test func missingKeysFallBack() {
        let info = AppInfo(infoDictionary: [:], operatingSystemVersion: Self.macOS26)
        #expect(info.name == "AutoClicker")
        #expect(info.versionAndBuild == "? (?)")
    }

    @Test func macOSVersionKeepsANonZeroPatch() {
        let version = OperatingSystemVersion(majorVersion: 15, minorVersion: 6, patchVersion: 1)
        #expect(AppInfo.versionString(version) == "15.6.1")
    }

    @Test func currentReadsTheHostBundle() {
        let info = AppInfo.current()
        #expect(!info.version.isEmpty)
        #expect(!info.build.isEmpty)
    }
}
