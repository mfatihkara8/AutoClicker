extension Comparable {
    /// Returns this value limited to `range`. The editors use it so that typed or stepped input can never leave the
    /// supported range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
