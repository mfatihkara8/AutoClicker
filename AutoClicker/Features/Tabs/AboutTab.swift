import AppKit
import SwiftUI

/// The About tab: the app icon, name and version, the Accessibility permission state, the GitHub link, the license
/// and Report a Bug… (SPEC §3.5).
struct AboutTab: View {
    let viewModel: MainViewModel
    let appInfo: AppInfo
    /// The prefilled bug report link, or `nil` if it could not be built, in which case the button is disabled.
    let bugReportURL: URL?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            header
            permissionState
            links
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(spacing: 6) {
            // Implicitly unwrapped in AppKit; bound here so a missing icon leaves a gap instead of a crash.
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
            }
            Text(verbatim: appInfo.name)
                .font(.title.weight(.semibold))
            Text("Version \(appInfo.versionAndBuild)")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .accessibilityIdentifier("appVersion")
        }
    }

    @ViewBuilder private var permissionState: some View {
        if viewModel.isAccessibilityTrusted {
            Label {
                Text("Accessibility permission granted")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .accessibilityIdentifier("aboutPermissionState")
        } else {
            VStack(spacing: 8) {
                Label {
                    Text("Accessibility permission missing")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                }
                Button("Open System Settings", action: viewModel.openAccessibilitySettings)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("aboutPermissionState")
        }
    }

    private var links: some View {
        VStack(spacing: 8) {
            if let repositoryURL = BugReportLink.repositoryURL {
                Link(destination: repositoryURL) {
                    Label("AutoClicker on GitHub", systemImage: "link")
                }
            }
            Text("MIT License")
                .foregroundStyle(.secondary)
            Button("Report a Bug…", systemImage: "ladybug") {
                if let bugReportURL {
                    openURL(bugReportURL)
                }
            }
            .disabled(bugReportURL == nil)
            .help("Opens a new bug report on GitHub, prefilled with the app and macOS versions")
            .accessibilityIdentifier("reportBugButton")
        }
    }
}
