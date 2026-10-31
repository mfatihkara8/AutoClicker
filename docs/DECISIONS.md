# Architecture Decision Records

Each record is short and has three parts: **Context**, **Decision** and **Consequences**.

Never edit a past decision. To change one, add a new ADR that supersedes it and mark the old one as **Superseded by ADR-xxx**.

---

## ADR-001: App Sandbox off, distribution outside the Mac App Store
**Status:** Accepted. The signing and notarization part is superseded by [ADR-010](#adr-010-releases-signed-with-an-apple-development-certificate-not-notarized).

- **Context:** A sandboxed app cannot post synthetic mouse events with `CGEvent`. In practice it also cannot obtain Accessibility trust.
- **Decision:** App Sandbox is disabled. The app is distributed directly, signed with a Developer ID and notarized.
- **Consequences:**
  - The app cannot be published on the Mac App Store.
  - Hardened Runtime stays on, because notarization requires it.

## ADR-002: Global hotkeys via Carbon `RegisterEventHotKey`
**Status:** Accepted

- **Context:**
  - `CGEvent.tapCreate` and `NSEvent.addGlobalMonitorForEvents` for key events both require Input Monitoring permission.
  - `NSEvent` global monitors also cannot consume events.
- **Decision:**
  - Use Carbon `RegisterEventHotKey` for F6 (start/stop).
  - Use it for ESC (emergency stop) as well, but register ESC only while clicking is active.
- **Consequences:**
  - No Input Monitoring permission is needed, and idle CPU cost is zero.
  - Carbon's C callback cannot capture Swift context, so context is passed through a `userData` pointer.
  - Recording macros (Phase 3) will need an event tap, which requires a new ADR.

## ADR-003: Swift 6, SwiftUI with `@Observable`, macOS 14+
**Status:** Accepted

- **Context:** macOS 14 is the first version with the Observation framework, and Swift 6 catches data races at compile time.
- **Decision:**
  - Use Swift 6 language mode with strict concurrency.
  - Use `@Observable` instead of `ObservableObject`.
  - Set the deployment target to macOS 14.
- **Consequences:**
  - Users on macOS 13 or older are not supported.
  - Every type that crosses a concurrency boundary must be `Sendable`.

## ADR-004: Click counter guarded by `OSAllocatedUnfairLock`
**Status:** Accepted

- **Context:**
  - The counter is written by the click queue and read by the UI.
  - `Synchronization.Atomic` requires macOS 15.
  - Hopping to `MainActor` on every click would flood the UI at high click rates.
- **Decision:** guard the counter with `OSAllocatedUnfairLock` (macOS 13+). The UI samples it at 10–20 Hz.
- **Consequences:**
  - The displayed count may lag by up to about 100 ms, which is acceptable.
  - The final value is read when the engine stops.

## ADR-005: Deadline-based click scheduling
**Status:** Accepted

- **Context:** a `sleep(interval)` loop accumulates drift, because posting the event and waking the thread both add time to each iteration.
- **Decision:**
  - Compute each click's absolute deadline as `start + n × interval`, plus jitter.
  - Wait for it with `DispatchSourceTimer` (low leeway) on a dedicated serial queue, or with a `ContinuousClock` deadline.
- **Consequences:** the click rate stays accurate over long runs, as SC-6 requires.

## ADR-006: Coordinates stored in CG global space
**Status:** Accepted

- **Context:**
  - CGEvent uses a top-left origin on the main display.
  - AppKit (`NSEvent.mouseLocation`, `NSScreen.frame`) uses a bottom-left origin.
  - Mixing the two breaks positions, especially on multi-monitor setups.
- **Decision:**
  - All stored and engine-facing coordinates use CG global space.
  - Conversion happens only in `ScreenGeometry`.
- **Consequences:** a single, unit-tested place owns the coordinate math.

## ADR-007: Settings persisted via `SettingsStore` on `UserDefaults`
**Status:** Accepted

- **Context:** `@AppStorage` does not work inside `@Observable` classes.
- **Decision:** a `SettingsStore` reads and writes a `Codable` settings value in `UserDefaults`. The ViewModel saves changes through it.
- **Consequences:**
  - One storage key and one versioned schema.
  - Easy to unit test with a separate `UserDefaults` suite.

## ADR-008: User-configurable start/stop hotkey, recorded with a scoped local key monitor
**Status:** Accepted

- **Context:**
  - Users want to change the start/stop hotkey (F6 may clash with other apps or keyboards). This pulls the Phase 2 "hotkey recorder" forward into the 0.1.0 release.
  - Carbon `RegisterEventHotKey` needs a virtual key code and Carbon modifier flags. SwiftUI `onKeyPress` only reports characters, which are layout-dependent and do not cover function keys reliably.
  - ADR-002 rules out event taps and `NSEvent` *global* monitors because they need Input Monitoring permission. An `NSEvent` *local* monitor only sees events sent to this app's own windows and needs no permission.
- **Decision:**
  - Only the start/stop hotkey is configurable. The ESC emergency stop stays fixed.
  - A recorder captures the next key-down with `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`. The monitor is installed only while the recorder is active in the main window and removed as soon as a key is captured or recording is cancelled. It lives behind a protocol so the ViewModel stays testable.
  - Accepted shortcuts: F1–F20 alone, or any other key combined with at least one of ⌘, ⌥ or ⌃. Shift alone is not enough, and Esc is reserved for the emergency stop and cancels recording.
  - If the new shortcut cannot be registered (for example, another app owns it), the previous shortcut stays active and a warning is shown.
  - The shortcut is persisted with the rest of the settings (one key, versioned schema, as in ADR-007), so the schema moves to version 2 with a migration from version 1 that defaults to F6.
- **Consequences:**
  - Still no Input Monitoring permission, and no key monitoring outside of an explicit recording session.
  - Global monitors and event taps remain forbidden.

## ADR-009: Modifier clicks via event flags only
**Status:** Accepted

- **Context:** users want to click while Shift, Control, Option and/or Command are held (multi-select, open in new tab, context menus). There are two ways to do that: set `CGEventFlags` on the posted mouse events, or post real modifier key-down/key-up events around each click.
- **Decision:** set the flags on each mouse-down/up event only (`maskShift`, `maskControl`, `maskAlternate`, `maskCommand`). Never post modifier key events.
- **Consequences:**
  - A modifier can never be left stuck down, even if the app crashes mid-click.
  - Standard AppKit apps (Finder, browsers, editors) read the flags from the mouse event and behave as expected.
  - Apps that poll the real keyboard state, such as some games, may not see the modifier. Supporting them would need key events and a new ADR.

## ADR-010: Releases signed with an Apple Development certificate, not notarized
**Status:** Accepted (2026-10-29). Supersedes the signing part of ADR-001.

- **Context:**
  - ADR-001 planned Developer ID signing and notarization. Both require a paid Apple Developer Program membership, which the project does not have.
  - The free account only offers an Apple Development certificate.
  - Ad-hoc signing would change the app's signature on every build. Users would then have to grant Accessibility again after each update.
- **Decision:**
  - Releases are signed with the team's Apple Development certificate, with the Hardened Runtime, a secure timestamp and no `get-task-allow`.
  - They are packaged as a signed DMG and published on GitHub Releases without notarization.
  - The README explains the first-launch warning and the "Open Anyway" step.
- **Consequences:**
  - Gatekeeper warns on the first launch, and users open the app once through *System Settings → Privacy & Security → Open Anyway*.
  - The signature stays stable across releases while the certificate's name stays the same, so the Accessibility permission survives updates.
  - The signature shows the certificate holder's Apple ID email and name.
  - Moving to Developer ID later changes the signature once, so users grant Accessibility again. The notarization steps are ready in [RELEASING.md](RELEASING.md#notarization).
