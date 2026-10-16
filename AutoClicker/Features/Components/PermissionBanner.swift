import SwiftUI

/// Warning banner shown while Accessibility permission is missing.
///
/// The banner renders nothing once `isTrusted` is true, so it disappears on its own as soon as
/// `PermissionManager` observes the grant.
struct PermissionBanner: View {
    let isTrusted: Bool
    let onOpenSettings: () -> Void
    let onRequestAccess: () -> Void

    var body: some View {
        if !isTrusted {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Accessibility permission required")
                        .font(.headline)
                    Text(
                        "AutoClicker needs Accessibility access to post clicks. Enable it in System Settings > Privacy & Security > Accessibility."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button("Open System Settings", action: onOpenSettings)
                            .buttonStyle(.borderedProminent)
                        Button("Request Access", action: onRequestAccess)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.yellow.opacity(0.4)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("permissionBanner")
        }
    }
}

#Preview("Missing permission") {
    PermissionBanner(isTrusted: false, onOpenSettings: {}, onRequestAccess: {})
        .padding()
        .frame(width: 420)
}

#Preview("Trusted") {
    PermissionBanner(isTrusted: true, onOpenSettings: {}, onRequestAccess: {})
        .padding()
        .frame(width: 420)
}
