import SwiftUI

/// Placeholder main window. Replaced by the card-based UI in M5 (T-502).
struct MainView: View {
    var body: some View {
        VStack {
            Image(systemName: "cursorarrow.click.2")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("AutoClicker")
        }
        .padding()
    }
}

#Preview {
    MainView()
}
