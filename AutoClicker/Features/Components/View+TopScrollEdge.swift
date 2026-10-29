import SwiftUI

extension View {
    /// Hides the top scroll edge effect of a scroll view that sits under the toolbar.
    ///
    /// On macOS 26 and later every `Form` paints a scroll edge band under the toolbar that lights up on hover, even
    /// though the tabs never scroll at the default window size (SPEC §3.5). The Click tab has two forms, so it showed
    /// two separate bands. Earlier systems have no such effect.
    @ViewBuilder
    func hidingTopScrollEdgeEffect() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}
