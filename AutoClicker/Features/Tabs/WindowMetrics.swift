import CoreGraphics

/// The main window's default and minimum content size (SPEC §3.5: no scrolling at the default size).
///
/// Every tab is laid out to fit this size. The window can grow but never shrinks below it.
enum WindowMetrics {
    static let defaultContentSize = CGSize(width: 560, height: 520)
}
