# Architecture

This document describes how the requirements in [SPEC.md](SPEC.md) are structured in code. Rationale for the fixed choices lives in [DECISIONS.md](DECISIONS.md).

## Layers

```
┌──────────────────────── MainActor ────────────────────────┐
│  Views (SwiftUI)                                          │
│    MainView, cards, PermissionBanner, MenuBarContent      │
│          │ bindings / intents                             │
│          ▼                                                │
│  MainViewModel (@Observable)    PermissionManager         │
│    - owns ClickConfiguration     (@Observable, polls AX)  │
│    - samples ClickCounter @ 10–20 Hz                      │
│    - saves via SettingsStore                              │
└──────────┬───────────────────────────────▲────────────────┘
           │ start(config) / stop()        │ onStop(reason) (hops to MainActor)
           ▼                               │
┌──────────────── Click queue (serial DispatchQueue) ───────┐
│  ClickEngine                                              │
│    ClickScheduler  ──deadline──▶  tick()                  │
│    tick(): FailsafeMonitor.check → resolve target         │
│            → EventPosting.post(click) → ClickCounter += 1 │
│            → StopCondition.isSatisfied?                   │
└───────────────────────────────────────────────────────────┘
           ▲
           │ Carbon hotkey callbacks (main run loop)
   CarbonHotkeyManager (HotkeyProviding): F6 toggles, ESC stops
```

**Rules:**
- Only the ViewModel talks to the engine.
- The engine never imports SwiftUI and never references the ViewModel.
- Cross-boundary values (`ClickConfiguration`, `StopReason`) are `Sendable` value types.

## Folder layout

```
AutoClicker/                      Xcode project root
├── AutoClicker/
│   ├── App/
│   │   ├── AutoClickerApp.swift        @main; single Window(id: "main") + MenuBarExtra; composition root
│   │   ├── AppDelegate.swift           keeps the app alive when the main window closes
│   │   └── Diagnostics/                `#if DIAGNOSTICS` only (Debug and --profiling builds, never shipped):
│   │                                   DiagnosticsMode/Session (env var → throwaway settings, no-op poster, fake
│   │                                   trust), SnapshotDriver (diagnose-ui.sh), DryRunDriver (SC-15 CPU),
│   │                                   LiveCheckDriver (live-check.sh, real events), ShowcaseDriver (showcase.sh)
│   ├── Features/
│   │   ├── Main/
│   │   │   ├── MainView.swift          top mode: TabView(.tabBarOnly); sidebar mode: NavigationSplitView (15+); banner + toolbar per tab
│   │   │   ├── ToolbarRunPresentation.swift toolbar status/tooltip text (tested)
│   │   │   ├── AppTab.swift            .main/.click/.profiles/.shortcuts/.about
│   │   │   ├── ProfilePresentation.swift "Profile: Name (modified)" + Save Changes title (tested)
│   │   │   ├── ProfileNameRejection+Display.swift
│   │   │   ├── WindowNavigation.swift  @Observable selected tab (not persisted; resets to Main)
│   │   │   ├── AppCommands.swift       About → About tab, ⌘, → Shortcuts tab, Help → Report a Bug…
│   │   │   ├── MainViewModel.swift     @Observable @MainActor
│   │   │   └── StopReason+Display.swift localized stop-reason text (kept out of Core)
│   │   ├── Tabs/                       MainTab (+ ClickCountView, ActiveProfileLine), ClickTab (two grouped Forms), ProfilesTab,
│   │   │                               ShortcutsTab, AboutTab;
│   │   │                               SettingsSummary, AppInfo, BugReportLink (pure, tested);
│   │   │                               WindowMetrics (default/min content size 760×520; sidebarWidth 200 —
│   │   │                               MainView raises the window minimum by it in the sidebar layout)
│   │   ├── Components/                 PermissionBanner, StartStopButton (large + round icon), RunStatusIndicator, ClickTypeSection,
│   │   │                               IntervalSection, TargetSection, StopConditionSection,
│   │   │                               ModifierToggleRow, KeyCap, NumberField, WarningLabel; pure clamping
│   │   │                               editors (ClickIntervalEditor, ClickTargetEditor, StopConditionEditor,
│   │   │                               ClickSequenceEditor, PositionOffsetEditor) and ClickTargetMemory (session-only
│   │   │                               last fixed point / point list); SequenceEditorSheet + SequencePointPicking;
│   │   │                               ProfileNameSheet
│   │   └── MenuBar/
│   │       ├── MenuBarContent.swift
│   │       ├── MenuBarLabel.swift      idle/running SF Symbol; reads only isRunning
│   │       └── MenuBarPresentation.swift pure status/title text, unit-tested
│   ├── Core/
│   │   ├── Engine/
│   │   │   ├── ClickEngine.swift
│   │   │   ├── ClickScheduler.swift
│   │   │   ├── ClickConfiguration.swift
│   │   │   ├── ClickType.swift
│   │   │   ├── ClickPoint.swift        sequence point + delay before its click
│   │   │   ├── PositionOffset.swift    uniform disk sampling for the random offset (ADR-012)
│   │   │   ├── ClickModifiers.swift    option set ⇧ ⌃ ⌥ ⌘, stored as names
│   │   │   ├── StopCondition.swift
│   │   │   ├── StopReason.swift
│   │   │   └── ClickCounter.swift
│   │   ├── Events/
│   │   │   ├── EventPosting.swift      protocol
│   │   │   └── CGEventPoster.swift
│   │   ├── Hotkeys/
│   │   │   ├── Hotkey.swift            key code + Carbon modifiers (+ keyLabel); Codable; .f6, .escape
│   │   │   ├── VirtualKeyCode.swift    kVK_* values, F1–F20, fixed key names
│   │   │   ├── ShortcutValidator.swift ADR-008 rules; AppKit → Carbon modifier mapping
│   │   │   ├── ShortcutRecording.swift protocol + RecordedKey.swift
│   │   │   ├── LocalShortcutRecorder.swift local keyDown monitor, only while recording
│   │   │   ├── HotkeyProviding.swift   protocol + HotkeyRegistrationError
│   │   │   └── CarbonHotkeyManager.swift
│   │   ├── Permissions/
│   │   │   ├── PermissionChecking.swift protocol
│   │   │   ├── AccessibilityPermissionChecker.swift
│   │   │   └── PermissionManager.swift @Observable @MainActor
│   │   ├── Safety/
│   │   │   ├── FailsafeChecking.swift  protocol + FailsafeDecision
│   │   │   └── FailsafeMonitor.swift
│   │   └── Geometry/
│   │       └── ScreenGeometry.swift
│   ├── Services/
│   │   ├── AppSettings.swift           configuration + toggleHotkey + profiles + activeProfileID
│   │   ├── Profile.swift               named ClickConfiguration snapshot + name rules (Phase 2)
│   │   └── SettingsStore.swift
│   ├── AppIcon.icon/                   Icon Composer icon (light/dark/tinted), generated by scripts/generate-app-icon.swift
│   └── Assets.xcassets                 AccentColor. Info.plist is generated (GENERATE_INFOPLIST_FILE);
│                                       sandbox/hardened runtime are build settings
├── .github/ISSUE_TEMPLATE/bug_report.yml  issue form prefilled by BugReportLink (app-version, macos-version)
├── scripts/
│   ├── build-release.sh                signed Release build + DMG (--profiling: keeps get-task-allow, no DMG)
│   ├── generate-app-icon.swift         regenerates AppIcon.icon (run: swift scripts/generate-app-icon.swift)
│   └── measure-performance.sh          samples a running app's CPU/RSS each second, then runs leaks (SC-6, SC-11)
├── AutoClickerTests/                  Swift Testing
│   ├── Mocks/                          MockEventPoster, MockPermissionChecker, MockHotkeyProvider, MockFailsafe, MockShortcutRecorder
│   ├── Support/                        test helpers (CallRecorder, waitUntil, drain, TestDefaultsSuite)
│   ├── ClickEngineTests.swift
│   ├── ClickSchedulerTests.swift
│   ├── StopConditionTests.swift
│   ├── ScreenGeometryTests.swift
│   └── SettingsStoreTests.swift
└── AutoClickerUITests/                XCTest UI tests
```

## Type responsibilities

### Engine (`Core/Engine`)

| Type | Kind | Responsibility |
|---|---|---|
| `ClickType` | `enum`, `Sendable`, `Codable` | `.left`, `.right`, `.middle`, `.double` |
| `ClickTarget` | `enum` | `.currentCursor`, `.fixed(CGPoint)` or `.sequence([ClickPoint])` (≤ 50 points). Points are in CG global space. |
| `ClickPoint` | `struct` | One sequence point: CG global `point` and `delayMilliseconds`, the wait before its click (ADR-011). |
| `Profile` | `struct` | A named `ClickConfiguration` snapshot with `id`; owns the name rules (normalize, reject, repair) (ADR-013). |
| `ClickInterval` | `struct` | Hours, minutes, seconds and milliseconds. Converts to `Duration` and clamps to ≥ 1 ms. Has an optional jitter in ms, capped at `(duration − 1 ms) / 2` so consecutive deadlines stay ≥ 1 ms apart; the scheduler adds `jitterOffset()` to each absolute deadline and never accumulates it. |
| `StopCondition` | `enum` | `.never`, `.afterClicks(Int)` or `.afterDuration(Duration)`. Exposes `isSatisfied(clicks:elapsed:)`. |
| `ClickModifiers` | `OptionSet`, `Sendable`, `Codable` | Shift, Control, Option, Command held for every click. Encoded as an array of names in ⌃⌥⇧⌘ order. |
| `ClickConfiguration` | `struct`, `Sendable`, `Codable` | Aggregates the click type, modifiers, interval, target, stop condition and `positionOffset` (0–200 pt). It is the persisted working configuration and the profile snapshot. |
| `ClickCounter` | `final class`, `Sendable` | Wraps `OSAllocatedUnfairLock<Int>` and provides `increment()`, `value` and `reset()`. |
| `ClickScheduler` | `final class` | Drives the click loop on a serial queue using `DispatchSourceTimer`. Computes absolute deadlines over a cyclic `Steps` list: tick *n* is due at `start + Σ steps(1…n)`, plus jitter. A single interval is the one-step list; a sequence's steps are its points' delays (ADR-011). Jitter is capped at (shortest step − 1 ms) / 2 so ticks never reorder. |
| `PositionOffset` | `enum` | Draws the per-click offset uniformly from a disk (angle 2π·a, distance r·√u); radius 0 draws nothing (ADR-012). |
| `ClickEngine` | `final class` | Owns the scheduler and coordinates each tick: resolve the base point (cursor, fixed, or `points[(n−1) mod k]`), add the offset (fixed and sequence only), run the failsafe on the cursor and the offset point, post, count, check the stop condition. An empty sequence ends at once with `.conditionMet`. Takes `start(_:)` and `stop()`. Reports the end of a run through `onStop(StopReason)`. |
| `StopReason` | `enum` | `.user`, `.hotkey`, `.emergencyEscape`, `.cornerFailsafe`, `.conditionMet` or `.permissionLost` |

`ClickEngine` does the following on each tick:
1. Read the cursor and resolve the target position (`.currentCursor` → cursor, skipped if unreadable; `.fixed(p)` → `p`).
2. Run the failsafe check (`FailsafeChecking.evaluate(cursor:target:)`): `.stopCornerReached` stops the run, `.skipInsideOwnWindow` skips the click without counting it and sets `isSkippingInsideOwnWindow`.
3. Post the click.
4. Increment the shared total `ClickCounter` and the per-run count. The engine never resets the total; only the Reset button does.
5. Check the stop condition against the per-run count and the tick's scheduled time.

The first tick fires one interval after `start`. `onStop(StopReason)` is called exactly once per run, asynchronously on the click queue; the ViewModel hops to the main actor itself. `stop(reason:)` defaults to `.user`.

### Services and adapters

| Type | Responsibility |
|---|---|
| `EventPosting` | `func post(_ type: ClickType, at point: CGPoint, modifiers: ClickModifiers)` |
| `CGEventPoster` | Implements `EventPosting`. Posts mouse-down/up events through a `.hidSystemState` source to `.cghidEventTap`:<br>• Middle click uses `.otherMouseDown/Up` with `.center`.<br>• Double click sets `kCGMouseEventClickState` to 2 on the second pair.<br>• Every event's `flags` are set to exactly the configured modifiers (empty for a plain click), so held keys never leak in (ADR-009). |
| `Hotkey` | `Hashable`, `Sendable` value: Carbon key code and modifiers. Provides `.f6` and `.escape`. |
| `HotkeyProviding` | `@MainActor`. `register(_ hotkey:, handler:) throws` (re-registering replaces the handler), `unregister(_:)`, `unregisterAll()` and `isRegistered(_:)`. Failures throw `HotkeyRegistrationError`. |
| `CarbonHotkeyManager` | Implements `HotkeyProviding` with `RegisterEventHotKey`:<br>• The handler context is passed via `userData`.<br>• The Carbon event handler is installed lazily on the first registration.<br>• All hotkeys are unregistered in an `isolated deinit`. |
| `PermissionChecking` | `isTrusted` and `requestTrust()` |
| `AccessibilityPermissionChecker` | Wraps `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions`. |
| `PermissionManager` | Exposes the current state to the UI and opens System Settings:<br>• While permission is missing and the window is visible, it polls about every 1 s.<br>• It stops polling once permission is granted. |
| `FailsafeChecking` | `evaluate(cursor:target:) -> FailsafeDecision` (`.proceed`, `.skipInsideOwnWindow`, `.stopCornerReached`). The engine depends only on this protocol. |
| `FailsafeMonitor` | Implements `FailsafeChecking`, `Sendable` via a lock; the main actor pushes snapshots with `update(geometry:)` / `update(ownWindowFrames:)`, and `ownWindowFrames(geometry:)` snapshots visible, non-minimized windows. Does two checks:<br>• `shouldStop(cursor:)` returns true when the cursor is within 2 px of a screen corner.<br>• `isInsideOwnWindow(_ point:)` checks the point against window frames snapshotted on the main actor. |
| `ScreenGeometry` | `Sendable` snapshot of the screen frames (`current()` reads `NSScreen` on the main actor). The only place that converts between AppKit and CG coordinates. Provides the screen corners, `isNearCorner(_:tolerance:)`, and the current cursor position via `CGEvent(source: nil)?.location` (optional; `nil` when unavailable). |
| `SettingsStore` | `@MainActor`. Loads and saves `AppSettings` (`configuration`, `toggleHotkey`, `profiles`, `activeProfileID`) as a version 4 JSON envelope (SPEC §7.4) in an injected `UserDefaults`. Versions 1 to 3 migrate (F6 for v1, no modifiers for v1/v2, offset 0 and no profiles for all); profile names are repaired and a dangling active id becomes `nil`. Missing, corrupt or unknown-version data loads the defaults; a stored shortcut the validator rejects falls back to F6. Debouncing is the ViewModel's job. |
| `ShortcutValidator` | Pure ADR-008 rules: F1–F20 alone, otherwise ⌘/⌥/⌃ required; Shift-only, modifier-only and Esc rejected. |
| `LocalShortcutRecorder` | Implements `ShortcutRecording` with an `NSEvent` local monitor installed only between `begin` and the captured key or `cancel`; swallows the captured event. While recording, the ViewModel unregisters the current start/stop hotkey so it can be captured, and restores it afterwards. |

## Key flows

**Start:**
1. The user clicks Start or presses F6.
2. `MainViewModel` checks permission and snapshots the configuration.
3. `MainViewModel` registers the ESC hotkey and calls `engine.start(config)`.
4. A UI sampling timer starts.

**Stop:** a stop can come from four places:
- the user,
- F6 or ESC,
- a failsafe,
- the stop condition.

Each one leads to `engine.stop()`, then `onStop(reason)`, then the ViewModel on the main actor. The ViewModel then:
- unregisters ESC,
- stops the sampling timer,
- reads the final count,
- shows the stop reason.

**Pick Location:**
1. The ViewModel runs a 3 s countdown on the main actor, with a purpose: the fixed target or a new sequence point.
2. It reads `ScreenGeometry.currentCursorLocation()`.
3. It stores the result as `.fixed(point)`, or appends a `ClickPoint` whose delay is the interval in ms (clamped).

**Profiles:** the ViewModel holds `profiles` and `activeProfileID` next to the working configuration. Applying copies a snapshot into `configuration` (rejected while clicking or picking); every profile operation saves immediately through `SettingsStore` (ADR-013).

## Composition
`AutoClickerApp` owns `MainViewModel` as `@State`, so clicking continues while the window is closed. It calls `activate()` (registers the saved start/stop shortcut, F6 by default) and flushes pending settings on `willTerminateNotification`. When the process runs as the unit-test host (`XCTestConfigurationFilePath` is set), it skips `activate()` and uses a throwaway `UserDefaults` suite, so tests never register real hotkeys or touch the user's settings.

`AutoClickerApp` builds the concrete dependencies and injects them into `MainViewModel` through its initializer:
- `CGEventPoster`,
- `CarbonHotkeyManager`,
- `AccessibilityPermissionChecker`,
- `SettingsStore`.

Tests inject the mocks from `AutoClickerTests/Mocks`. Singletons are not used.
