/// What the Edit Points sheet needs from the view model besides the points: the Add Point countdown, whether a point
/// can be added, the run lock, and the Add Point intents.
///
/// Grouped so the Target section can hand it through without knowing the view model.
struct SequencePointPicking {
    /// The remaining Add Point countdown seconds, or `nil` when no point is being picked.
    let countdown: Int?
    /// Whether Add Point can start: idle, no countdown in progress, and fewer than `ClickTarget.maxSequencePoints`.
    let canAddPoint: Bool
    /// Whether editing is locked because a run is active.
    let isLocked: Bool
    let onAddPoint: () -> Void
    let onCancelAddPoint: () -> Void
}

extension SequencePointPicking {
    /// An idle value with no-op intents, for previews.
    static var preview: SequencePointPicking {
        SequencePointPicking(countdown: nil, canAddPoint: true, isLocked: false, onAddPoint: {}, onCancelAddPoint: {})
    }
}
