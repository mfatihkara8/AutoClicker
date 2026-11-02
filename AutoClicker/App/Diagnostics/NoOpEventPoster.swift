#if DIAGNOSTICS
    import CoreGraphics

    /// An `EventPosting` that posts nothing, so a diagnostics run can drive the engine without clicking anywhere.
    ///
    /// The engine still schedules every tick, evaluates the failsafe and increments the counter, so the CPU cost of a
    /// run is the same as a real one minus the cost of posting the events themselves.
    struct NoOpEventPoster: EventPosting {
        func post(_ type: ClickType, at point: CGPoint, modifiers: ClickModifiers) {}
    }
#endif
