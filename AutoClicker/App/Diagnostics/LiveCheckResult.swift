#if DIAGNOSTICS
    import CoreGraphics

    /// What a live check found, written as JSON for `scripts/live-check.sh`, which compares `run` with the clicks the
    /// click target received.
    struct LiveCheckResult: Codable {
        struct Point: Codable {
            var x: Double
            var y: Double

            init(_ point: CGPoint) {
                x = point.x
                y = point.y
            }
        }

        /// One Add Point: where the cursor was put, and what the real countdown appended.
        struct AddedPoint: Codable {
            var requested: Point
            var countdownStarted = false
            var countdownSeconds = 0.0
            var appended: Point?
            var delayMilliseconds: Int?
            /// Where the cursor was when the countdown ended; differs from `requested` if someone moved the mouse.
            var cursorAtEnd: Point?
            var distance: Double?
            var passed = false
        }

        struct AddPoint: Codable {
            /// How Edit Points and Add Point were pressed: through the Accessibility API, or the view model as fallback.
            var method = ""
            var sheetOpened = false
            var points: [AddedPoint] = []
            var passed = false
        }

        struct Profiles: Codable {
            /// How the Profiles submenu was reached: the real menu bar extra's open menu, or the view model's bindings
            /// as fallback.
            var method = ""
            var itemsBefore: [StatusItemMenu.MenuItem] = []
            var itemsAfter: [StatusItemMenu.MenuItem] = []
            var activeBefore: String?
            var chosen = ""
            var activeAfter: String?
            var configurationMatchesChosen = false
            var passed = false
        }

        struct Run: Codable {
            var started = false
            var points: [Point] = []
            var positionOffset = 0
            var modifiers: ClickModifiers = []
            var clickType = ""
            var expectedClicks = 0
            var countedClicks = 0
            var stopReason: String?
            var durationSeconds = 0.0
            /// Whether none of the app's own windows was within the offset of the target window at start.
            var ownWindowsClear = false
        }

        var accessibilityTrusted = false
        var targetContent: Point?
        var addPoint = AddPoint()
        var profiles: Profiles?
        var run: Run?
        var notes: [String] = []
    }
#endif
