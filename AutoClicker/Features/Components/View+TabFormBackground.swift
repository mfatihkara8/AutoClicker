import SwiftUI

extension View {
    /// Keeps a tab's `Form` from drawing its own band under the toolbar.
    ///
    /// A grouped `Form` paints its scroll background up under the toolbar, and on macOS 26 that band lights up on hover
    /// even though the tabs never scroll at the default window size (SPEC §3.5). The Click tab has two forms, so it
    /// showed two separate bands, while the Main tab, which has no form, showed none. Hiding the form's own background
    /// lets the window background show through, exactly like the Main tab; the grouped sections keep their own fill.
    @ViewBuilder
    func tabFormBackground() -> some View {
        // The stack respects the toolbar's safe area, so clipping it keeps the form from drawing (and the system from
        // adding a scroll pocket) under the toolbar at all.
        VStack(spacing: 0) {
            if #available(macOS 26, *) {
                scrollContentBackground(.hidden)
                    .scrollEdgeEffectHidden(true, for: .top)
            } else {
                scrollContentBackground(.hidden)
            }
        }
        .clipped()
    }
}
