# Roadmap

Phase 1 is delivered in milestones M0–M6, completed in order. Each milestone ends in a buildable app with passing tests.

The individual tasks are listed in [TASKS.md](TASKS.md). Current progress is tracked in [TODO.md](../TODO.md).

## Phase 1: Core AutoClicker

### M0: Project setup
- **Goal:** an empty app that builds and runs, with the final folder structure.
- **Deliverables:**
  - An Xcode project configured for Swift 6, macOS 14, Sandbox off and Hardened Runtime on.
  - A fixed bundle ID and Development Team.
  - The folder skeleton from [ARCHITECTURE.md](ARCHITECTURE.md).
  - A test target.
  - A `swift-format` config.
- **Done when:**
  - `xcodebuild build` and `xcodebuild test` succeed.
  - The app launches with a placeholder window.

### M1: Permissions
- **Goal:** the Accessibility permission is detected and requested, and its state updates live.
- **Deliverables:** `PermissionChecking`, `AccessibilityPermissionChecker`, `PermissionManager` and `PermissionBanner`.
- **Done when:** SC-1 passes.

### M2: Click engine
- **Goal:** the engine posts accurate clicks at precise intervals, without any UI.
- **Deliverables:**
  - `ClickType`, `ClickInterval`, `StopCondition` and `ClickConfiguration`.
  - `EventPosting` and `CGEventPoster`.
  - `ClickCounter`, `ClickScheduler` and `ClickEngine`.
  - Unit tests.
- **Done when:**
  - The engine tests pass with `MockEventPoster`.
  - A manual check confirms all four click types.
  - A 60 s run at 10 ms is within ±2%.

### M3: Targeting and coordinates
- **Goal:** clicks land at the correct position on any display.
- **Deliverables:** `ScreenGeometry`, current and fixed targets, and Pick Location.
- **Done when:**
  - The geometry tests pass.
  - SC-7 passes.

### M4: Hotkeys and failsafes
- **Goal:** the user can always stop the clicker.
- **Deliverables:** `HotkeyProviding`, `CarbonHotkeyManager` (F6 and the scoped ESC) and `FailsafeMonitor`.
- **Done when:** SC-2, SC-3, SC-9 and SC-10 pass.

### M5: UI and persistence
- **Goal:** the full Phase 1 user experience.
- **Deliverables:**
  - `MainViewModel` with throttled counter sampling.
  - All the settings cards.
  - The status indicator and counter.
  - `SettingsStore`.
  - `MenuBarExtra`.
- **Done when:** SC-4, SC-5 and SC-8 pass.

### M6: Hardening and release
- **Goal:** prove that every success criterion passes, and prepare for distribution.
- **Deliverables:**
  - Instruments runs: Time Profiler, Allocations and Leaks.
  - A pass over all the success criteria.
  - A Release build and notarization notes in the README.
- **Done when:** SC-1 to SC-11 all pass, and `CHANGELOG.md` has a `0.1.0` entry.

## Phase 2: Productivity (planned)
- A configurable hotkey recorder for start/stop.
- Profiles: saved and named configurations.
- Multi-point and sequential clicking with a per-point delay.
- A random position offset within a radius.

## Phase 3: Macros (planned)
- Recording and playback of mouse and keyboard sequences.
- This requires `CGEvent.tapCreate` and **Input Monitoring** permission, so a new ADR is needed before work starts.
