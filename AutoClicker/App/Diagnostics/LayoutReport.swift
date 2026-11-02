#if DIAGNOSTICS
    import AppKit

    /// The text report written next to the snapshots: per state, the window's content size and every visible scroll
    /// view, with whether its document is taller than what it shows (it scrolls).
    @MainActor
    struct LayoutReport {
        private var lines: [String] = []

        /// Adds the entry for one snapshot of `window`.
        mutating func record(name: String, note: String, window: NSWindow) {
            let content = window.contentLayoutRect.size
            lines.append("\(name)")
            lines.append("  state: \(note)")
            lines.append(
                "  window frame: \(Self.format(window.frame.size)), content: \(Self.format(content)), "
                    + "content min: \(Self.format(window.contentMinSize))"
                    + (window.sheetParent == nil ? "" : " (sheet)"))
            let scrollViews = Self.visibleScrollViews(in: window)
            if scrollViews.isEmpty {
                lines.append("  scroll views: none")
            }
            for scrollView in scrollViews {
                // The toolbar overlaps the top of a full-size content view, so the insets are not visible space.
                let insets = scrollView.contentView.contentInsets
                let visible = scrollView.contentView.bounds.height - insets.top - insets.bottom
                let document = scrollView.documentView?.frame.height ?? 0
                let scrolls = document > visible + 0.5
                let frame = scrollView.convert(scrollView.bounds, to: nil)
                lines.append(
                    "  scroll view at x \(Int(frame.minX)) y \(Int(frame.minY)) size \(Self.format(frame.size)), "
                        + "insets top \(Int(insets.top)) bottom \(Int(insets.bottom)): "
                        + "document height \(Int(document.rounded())), visible \(Int(visible.rounded())) -> "
                        + (scrolls ? "SCROLLS by \(Int((document - visible).rounded())) pt" : "fits"))
            }
            lines.append("")
        }

        /// Adds a line that is not about a snapshot, such as a skipped state or a failure.
        mutating func note(_ text: String) {
            lines.append(text)
            lines.append("")
        }

        func write(to url: URL) throws {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }

        /// The scroll views in the window that are on screen: not hidden, not inside a hidden view, and not empty.
        private static func visibleScrollViews(in window: NSWindow) -> [NSScrollView] {
            guard let root = window.contentView?.superview ?? window.contentView else { return [] }
            var found: [NSScrollView] = []
            var pending: [NSView] = [root]
            while let view = pending.popLast() {
                if view.isHidden || view.alphaValue == 0 {
                    continue
                }
                if let scrollView = view as? NSScrollView, scrollView.frame.width > 1, scrollView.frame.height > 1 {
                    found.append(scrollView)
                }
                pending.append(contentsOf: view.subviews)
            }
            return found.sorted { lhs, rhs in
                let left = lhs.convert(lhs.bounds, to: nil)
                let right = rhs.convert(rhs.bounds, to: nil)
                return (left.minX, -left.maxY) < (right.minX, -right.maxY)
            }
        }

        private static func format(_ size: CGSize) -> String {
            "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
        }
    }
#endif
