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

### M7: Configurable hotkey and app assets
M7 was added after M5 and is done **before** M6, so that 0.1.0 ships with it.
- **Goal:** the user can choose the start/stop shortcut, and the app has its own icon.
- **Deliverables:**
  - `ShortcutRecording` and its local-monitor implementation ([ADR-008](DECISIONS.md#adr-008-user-configurable-startstop-hotkey-recorded-with-a-scoped-local-key-monitor)).
  - Settings schema version 2 with the start/stop shortcut, plus migration from version 1.
  - The recorder UI in the hotkey card, and the current shortcut shown in the menu bar extra.
  - A generated app icon in every macOS size and a matching accent color.
- **Done when:**
  - A changed shortcut works globally, survives a relaunch, and a taken shortcut keeps the old one with a warning.
  - The app shows its own icon in the Dock, Finder and the app switcher.

### M8: Modifier clicks
Added after M7 and done **before** M6, so that 0.1.0 ships with it.
- **Goal:** clicks can be sent with ⇧, ⌃, ⌥ and/or ⌘ held.
- **Deliverables:** `ClickModifiers` in `ClickConfiguration` (settings schema v3), event flags in `CGEventPoster` ([ADR-009](DECISIONS.md#adr-009-modifier-clicks-via-event-flags-only)), and the "Hold" row in the click type card.
- **Done when:** ⇧⌘-click selects several files in Finder, ⌘-click opens a link in a new browser tab, and the modifiers survive a relaunch.

### M9: Tabbed window
Added after M8 and done **before** M6, so that 0.1.0 ships with it.
- **Goal:** replace the single scrolling window with the four-tab layout from SPEC §3.5.
- **Deliverables:** the tab shell with the toolbar Start/Stop and menu commands, the Main, Click, Shortcuts and About tabs, and the bug report issue form.
- **Done when:** every tab fits the default window size without scrolling, on macOS 26 the tab bar is the system Liquid Glass one, and the menu commands select the right tabs.

## Phase 2: Productivity
Phase 2 is specified in [SPEC.md §7](SPEC.md#7-phase-2-requirements) and checked against SC-12 to SC-15.

### M10: Phase 2 model and settings schema
- **Goal:** one shared model for the whole phase, so that the engine, Click tab and profile work can run in parallel.
- **Deliverables:**
  - `ClickPoint` and the `.sequence` target.
  - `positionOffset`.
  - `Profile`, with the profiles in `AppSettings`.
  - Settings schema version 4, with migration from versions 1 to 3.
- **Done when:** schema version 4 round-trips every new field, older settings migrate, and invalid profile data is repaired.

### M11: Engine: sequences and position offset
- **Goal:** the engine clicks sequences on a cyclic deadline schedule and applies the random offset ([ADR-011](DECISIONS.md#adr-011-click-sequences-with-a-per-point-delay-on-a-cyclic-deadline-schedule), [ADR-012](DECISIONS.md#adr-012-random-position-offset-for-fixed-and-sequence-targets-only)).
- **Done when:** scheduler and engine tests cover point order, cyclic deadlines, skip-ahead, the offset disk and the failsafes with offsets.

### M12: Click tab: sequence editor and offset
- **Goal:** the user can build a sequence, set a random offset, and see both in the summaries.
- **Done when:** the Cursor, Fixed and Sequence modes, the Edit Points sheet with Add Point, and the offset row all work while the tab still fits 760×520.

### M13: Profiles
- **Goal:** save, apply, update, rename and delete named profiles from the Profiles tab and the menu bar ([ADR-013](DECISIONS.md#adr-013-profiles-as-named-configuration-snapshots-in-the-settings-envelope)).
- **Done when:** the profile operations are unit-tested in the view model, the Profiles tab and the menu bar submenu work, and the Main tab shows the active profile.

## Phase 3: Macros (planned)
- Recording and playback of mouse and keyboard sequences.
- This requires `CGEvent.tapCreate` and **Input Monitoring** permission, so a new ADR is needed before work starts.
