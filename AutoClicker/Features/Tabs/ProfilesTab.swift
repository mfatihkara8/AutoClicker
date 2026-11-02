import SwiftUI

/// The Profiles tab: the current settings with Save Changes and Save as New Profile…, then the saved profiles with
/// Apply, Rename… and Delete… (SPEC §7.3).
///
/// Applying is disabled while clicking, so a run keeps the configuration it started with. The form scrolls when the
/// list is longer than the window, but the save actions stay at the top, in reach.
struct ProfilesTab: View {
    let viewModel: MainViewModel

    /// What the name sheet is asking for, or `nil` while it is closed.
    @State private var nameRequest: NameRequest?
    /// The profile the delete confirmation asks about, or `nil` while it is closed.
    @State private var profilePendingDeletion: Profile?

    var body: some View {
        Form {
            currentSettingsSection
            profilesSection
        }
        .formStyle(.grouped)
        .tabFormBackground()
        .sheet(item: $nameRequest, content: nameSheet)
        .confirmationDialog(
            deletionTitle,
            isPresented: isConfirmingDeletion,
            titleVisibility: .visible,
            presenting: profilePendingDeletion
        ) { profile in
            Button("Delete", role: .destructive) {
                viewModel.deleteProfile(id: profile.id)
            }
            .accessibilityIdentifier("confirmDeleteProfileButton")
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The current settings stay as they are.")
        }
    }

    // MARK: - Current settings

    private var currentSettingsSection: some View {
        let summary = SettingsSummary(configuration: viewModel.configuration).text
        let presentation = viewModel.activeProfile.map {
            ProfilePresentation(name: $0.name, isModified: viewModel.isActiveProfileModified)
        }
        return Section("Current Settings") {
            LabeledContent {
                Text(verbatim: summary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(Text(verbatim: summary))
            } label: {
                if let presentation {
                    Text(verbatim: presentation.statusText)
                } else {
                    Text("No profile applied")
                }
            }
            .accessibilityIdentifier("currentSettingsSummary")

            HStack {
                if !viewModel.canSaveNewProfile {
                    Text(verbatim: Profile.NameRejection.tooManyProfiles.displayText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let presentation {
                    Button(action: viewModel.saveChangesToActiveProfile) {
                        Text(verbatim: presentation.saveChangesTitle)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .disabled(!presentation.isModified)
                    .help("Store the current settings in the active profile")
                    .accessibilityIdentifier("saveProfileChangesButton")
                }
                Button("Save as New Profile…") {
                    nameRequest = .new
                }
                .disabled(!viewModel.canSaveNewProfile)
                .help("Save the current settings as a new profile")
                .accessibilityIdentifier("saveNewProfileButton")
            }
        }
    }

    // MARK: - Saved profiles

    private var profilesSection: some View {
        Section("Saved Profiles") {
            if viewModel.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Profiles", systemImage: AppTab.profiles.systemImage)
                } description: {
                    Text(
                        """
                        A profile saves the click settings under a name, so you can switch between setups in one \
                        step. The start/stop shortcut is shared by all profiles.
                        """)
                }
                .accessibilityIdentifier("profilesEmptyState")
            } else {
                ForEach(viewModel.profiles) { profile in
                    row(for: profile)
                }
            }
        }
    }

    private func row(for profile: Profile) -> some View {
        let isActive = profile.id == viewModel.activeProfileID
        let summary = SettingsSummary(configuration: profile.configuration).text
        return HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
                // Kept in the layout when hidden, so every name starts at the same place.
                .opacity(isActive ? 1 : 0)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: profile.name)
                Text(verbatim: summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(Text(verbatim: summary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isActive ? .isSelected : [])

            Spacer(minLength: 8)

            Button("Apply") {
                viewModel.applyProfile(id: profile.id)
            }
            // Applying the active profile only does something once the settings were changed: it reverts them.
            .disabled(!viewModel.canApplyProfile || (isActive && !viewModel.isActiveProfileModified))
            .help("Replace the current settings with this profile")
            .accessibilityIdentifier("applyProfileButton")

            Menu {
                rowActions(for: profile)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Rename or delete this profile")
            .accessibilityLabel(Text("More actions for \(profile.name)"))
            .accessibilityIdentifier("profileActionsMenu")
        }
        .contextMenu {
            rowActions(for: profile)
        }
    }

    @ViewBuilder private func rowActions(for profile: Profile) -> some View {
        Button("Rename…") {
            nameRequest = .rename(profile)
        }
        Button("Delete…", role: .destructive) {
            profilePendingDeletion = profile
        }
    }

    // MARK: - Sheet and confirmation

    @ViewBuilder private func nameSheet(for request: NameRequest) -> some View {
        switch request {
        case .new:
            ProfileNameSheet(
                title: "Save as New Profile",
                confirmTitle: "Save",
                rejection: { viewModel.profileNameRejection(for: $0) },
                onConfirm: { viewModel.saveNewProfile(named: $0) }
            )
        case .rename(let profile):
            ProfileNameSheet(
                title: "Rename “\(profile.name)”",
                confirmTitle: "Rename",
                initialName: profile.name,
                rejection: { viewModel.profileNameRejection(for: $0, renaming: profile.id) },
                onConfirm: { viewModel.renameProfile(id: profile.id, to: $0) }
            )
        }
    }

    private var deletionTitle: Text {
        guard let profile = profilePendingDeletion else { return Text(verbatim: "") }
        return Text("Delete “\(profile.name)”?")
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(
            get: { profilePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    profilePendingDeletion = nil
                }
            }
        )
    }

    /// What the name sheet was opened for.
    private enum NameRequest: Identifiable {
        case new
        case rename(Profile)

        var id: String {
            switch self {
            case .new: "new"
            case .rename(let profile): profile.id.uuidString
            }
        }
    }
}
