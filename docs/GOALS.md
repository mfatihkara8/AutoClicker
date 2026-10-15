# Goals

## Product goals
1. **Lightweight:** the app uses about 0% CPU when idle and stays small in memory and on disk. It has no third-party dependencies.
2. **Reliable:**
   - Clicks land where and when the user configured them.
   - Timing does not drift, and positions are correct on every display.
3. **Safe:** the user can always stop the clicker, using F6, ESC or a screen corner. The app never clicks itself.
4. **Permission-friendly:**
   - Only Accessibility permission is required.
   - Its state is clear in the UI and updates live when it changes.
5. **Native:**
   - Looks and behaves like a modern macOS app.
   - Uses a compact window with an optional menu bar extra.
6. **Maintainable:** follows MVVM with a UI-independent engine that is testable through protocols.

## Non-goals (Phase 1)
- Macro recording and playback.
- A configurable hotkey recorder.
- Profiles.
- Multi-point or sequential clicking.
- Mouse movement simulation.
- Auto-update.
- Mac App Store distribution. This is not possible because the app cannot be sandboxed; see [ADR-001](DECISIONS.md#adr-001-app-sandbox-off-distribution-outside-the-mac-app-store).
- Supporting macOS versions older than 14.

## Success criteria
Phase 1 is done when all of these pass. M6 in the [roadmap](ROADMAP.md) verifies them.

| # | Criterion |
|---|---|
| SC-1 | After permission is granted, the banner disappears on its own within 2 s. |
| SC-2 | F6 starts and stops clicking even while the app is in the background. |
| SC-3 | ESC stops active clicking within 1 click. |
| SC-4 | A double click opens a folder in Finder and selects a word in TextEdit. |
| SC-5 | A middle click opens a link in a new browser tab. |
| SC-6 | Running for 60 s at a 10 ms interval:<br>• the actual click count is within ±2% of the expected count,<br>• CPU stays below 5%,<br>• memory does not grow. |
| SC-7 | Fixed-coordinate mode clicks the correct point on a secondary monitor. |
| SC-8 | Settings are preserved after the app is quit and relaunched. |
| SC-9 | Moving the cursor into a screen corner stops the engine. |
| SC-10 | A target inside the app's own window is skipped and a warning is shown. |
| SC-11 | Idle CPU is about 0%, and Instruments shows no leaks after repeated start/stop cycles. |
