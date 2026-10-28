import CoreGraphics

/// The main window's default and minimum content size (SPEC §3.5: no scrolling at the default size).
///
/// Every tab is laid out to fit this size. The window can grow but never shrinks below it. It is 760 wide rather than
/// 560 because the Click tab does not fit 560×520 in one column (measured about 550–640 pt of form content against
/// about 470 pt available), so it uses two columns instead of scrolling.
enum WindowMetrics {
    static let defaultContentSize = CGSize(width: 760, height: 520)
}
