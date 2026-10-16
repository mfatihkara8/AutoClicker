import SwiftUI

/// An orange warning line with a triangle icon, shared by the cards so every warning looks the same.
struct WarningLabel: View {
    let text: Text

    /// Creates a warning from a localized key.
    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    /// Creates a warning from text that is already localized, such as the view model's warnings.
    init(verbatim string: String) {
        text = Text(verbatim: string)
    }

    var body: some View {
        Label {
            text.fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.callout)
        .foregroundStyle(.orange)
    }
}

#Preview {
    VStack(alignment: .leading) {
        WarningLabel("Move the cursor outside the AutoClicker window to start clicking.")
        WarningLabel(verbatim: "F6 is used by another app. Use the Start button instead.")
    }
    .padding()
    .frame(width: 420)
}
