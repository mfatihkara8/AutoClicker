#if DIAGNOSTICS
    import AppKit

    /// Writes a PNG of a whole window, toolbar and title bar included, at the window's backing scale.
    ///
    /// It draws the window's frame view (the content view's superview) into a bitmap with `cacheDisplay`, which needs
    /// no Screen Recording permission. Materials such as Liquid Glass and vibrancy may come out flat, which is fine for
    /// checking layout. On macOS 26 the sidebar's glass panel, list included, comes out blank white (rendering the layer
    /// tree gives the same), and the selected tab's title is drawn white on its white pill.
    @MainActor
    struct WindowSnapshotter {
        let directory: URL

        enum SnapshotError: Error {
            case noView
            case noBitmap
            case noPNG
        }

        /// Draws `window` and writes it to `<directory>/<name>.png`.
        func capture(_ window: NSWindow, name: String) throws {
            guard let view = window.contentView?.superview ?? window.contentView else { throw SnapshotError.noView }
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            let bounds = view.bounds
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else { throw SnapshotError.noBitmap }
            view.cacheDisplay(in: bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw SnapshotError.noPNG }
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
#endif
