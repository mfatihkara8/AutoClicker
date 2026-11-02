import SwiftUI

/// A small sheet that asks for a profile name, for Save as New Profile… and Rename….
///
/// The confirm button stays disabled while the name is rejected. An empty name only disables it; any other rejection
/// is shown under the field, so the user knows why.
struct ProfileNameSheet: View {
    let title: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    /// Why a name cannot be used, or `nil` when it can.
    let rejection: @MainActor (String) -> Profile.NameRejection?
    /// Saves the name and returns why it was not saved, or `nil` to close the sheet.
    let onConfirm: @MainActor (String) -> Profile.NameRejection?

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(
        title: LocalizedStringKey,
        confirmTitle: LocalizedStringKey,
        initialName: String = "",
        rejection: @escaping @MainActor (String) -> Profile.NameRejection?,
        onConfirm: @escaping @MainActor (String) -> Profile.NameRejection?
    ) {
        self.title = title
        self.confirmTitle = confirmTitle
        self.rejection = rejection
        self.onConfirm = onConfirm
        _name = State(initialValue: initialName)
    }

    var body: some View {
        let rejection = rejection(name)
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(confirm)
                .accessibilityIdentifier("profileNameField")

            Group {
                if let rejection, rejection != .empty {
                    WarningLabel(verbatim: rejection.displayText)
                        .accessibilityIdentifier("profileNameRejection")
                } else {
                    Text("Up to \(Profile.maxNameLength) characters.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            // The hint and the warning take the same space, so the buttons do not jump while typing.
            .frame(minHeight: 32, alignment: .topLeading)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, action: confirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(rejection != nil)
                    .accessibilityIdentifier("profileNameConfirmButton")
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func confirm() {
        // Return also lands here, so the rejection is checked again rather than trusting the disabled button.
        guard rejection(name) == nil, onConfirm(name) == nil else { return }
        dismiss()
    }
}

#Preview {
    ProfileNameSheet(
        title: "Save as New Profile",
        confirmTitle: "Save",
        initialName: "Work",
        rejection: { Profile.nameRejection(for: $0, among: []) },
        onConfirm: { _ in nil }
    )
}
