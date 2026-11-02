import SwiftUI

/// The Main tab's "Profile: Name" or "Profile: Name (modified)" line, or nothing when no profile is active
/// (SPEC §7.3).
///
/// A view of its own so that only it reads the profiles: the Main tab re-evaluates as little as possible (SC-6).
struct ActiveProfileLine: View {
    let viewModel: MainViewModel

    var body: some View {
        if let profile = viewModel.activeProfile {
            let text = ProfilePresentation(name: profile.name, isModified: viewModel.isActiveProfileModified)
                .statusText
            Text(verbatim: text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(Text(verbatim: text))
                .accessibilityIdentifier("activeProfile")
        }
    }
}
