# Tasks

Phase 1 tasks are grouped by milestone (see [ROADMAP.md](ROADMAP.md)). Task IDs never change. To track progress, tick tasks off in [TODO.md](../TODO.md); do not change this file for that.

The format of each task is: **ID: Title**, then the files it touches, then **Done when**.

## M0: Project setup

- **T-001: Create the Xcode project**
  - **Files:** `AutoClicker.xcodeproj`
  - **Done when:**
    - The project uses the macOS App template with SwiftUI.
    - Swift 6 language mode and strict concurrency set to Complete are enabled.
    - The deployment target is macOS 14.0.
- **T-002: Configure signing and capabilities**
  - **Files:** build settings in `AutoClicker.xcodeproj` (`ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES`, `DEVELOPMENT_TEAM`)
  - **Done when:**
    - The bundle ID and Development Team are fixed.
    - App Sandbox is removed and Hardened Runtime is on.
    - A Debug build runs, and the Accessibility grant survives a rebuild.
- **T-003: Create the folder skeleton**
  - **Files:** the groups and folders listed in [ARCHITECTURE.md](ARCHITECTURE.md#folder-layout)
  - **Done when:** the folders match the documented layout, and the placeholder `MainView` builds. Empty folders are not tracked by git until they get their first file; placeholder files are not allowed because synchronized folders copy them into the bundle.
- **T-004: Add the test target and mocks folder**
  - **Files:** `AutoClickerTests/` (Swift Testing), `AutoClickerUITests/` (XCTest)
  - **Done when:** a trivial test passes with `xcodebuild test`, and `AutoClickerTests/Mocks/` exists.
- **T-005: Add the formatter config**
  - **Files:** `.swift-format`
  - **Done when:** `swift format lint -r AutoClicker AutoClickerTests` runs clean.
- **T-006: Record the build and test commands**
  - **Files:** `CLAUDE.md` and `README.md`
  - **Done when:** the exact `xcodebuild` commands, including how to run a single test, are documented.

## M1: Permissions

- **T-101: Add `PermissionChecking` and `AccessibilityPermissionChecker`**
  - **Files:** `Core/Permissions/`
  - **Done when:** the checker wraps `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions`, and the prompt is shown only when requested.
- **T-102: Add `PermissionManager`**
  - **Files:** `Core/Permissions/PermissionManager.swift`
  - **Done when:**
    - It is `@Observable @MainActor`.
    - It polls about every 1 s while permission is missing and the window is visible, and stops once permission is granted.
    - Unit tests with `MockPermissionChecker` pass.
- **T-103: Add `PermissionBanner`**
  - **Files:** `Features/Components/PermissionBanner.swift`
  - **Done when:**
    - The banner's button opens the `Privacy_Accessibility` pane.
    - The banner hides itself within 2 s of permission being granted (SC-1).

## M2: Click engine

- **T-201: Add the configuration value types**
  - **Files:** `ClickType`, `ClickTarget`, `ClickInterval`, `StopCondition` and `ClickConfiguration`
  - **Done when:**
    - All are `Sendable` and `Codable`.
    - `ClickInterval` clamps to at least 1 ms.
    - The `StopCondition` tests pass.
- **T-202: Add `EventPosting` and `CGEventPoster`**
  - **Files:** `Core/Events/`
  - **Done when:**
    - Left, right, middle (`.otherMouse*` with `.center`) and double (click state 2) clicks all work.
    - Events are posted to `.cghidEventTap`.
- **T-203: Add `ClickCounter`**
  - **Files:** `Core/Engine/ClickCounter.swift`
  - **Done when:** it is lock-based (`OSAllocatedUnfairLock`), and a concurrent increment test passes.
- **T-204: Add `ClickScheduler`**
  - **Files:** `Core/Engine/ClickScheduler.swift`
  - **Done when:**
    - It uses a `DispatchSourceTimer` on a serial queue, with absolute deadlines and jitter.
    - The drift test is within ±2% over 1,000 ticks.
- **T-205: Add `ClickEngine`**
  - **Files:** `Core/Engine/ClickEngine.swift`
  - **Done when:**
    - `start` and `stop` work and are idempotent.
    - `onStop(StopReason)` is called.
    - Tests with `MockEventPoster` cover the stop conditions and the posted click types.

## M3: Targeting and coordinates

- **T-301: Add `ScreenGeometry`**
  - **Files:** `Core/Geometry/ScreenGeometry.swift`
  - **Done when:**
    - It converts between AppKit and CG coordinates, provides the screen corners and reads the current cursor.
    - Unit tests cover multi-screen frames.
- **T-302: Resolve targets in the engine**
  - **Files:** `ClickEngine`
  - **Done when:** `.currentCursor` and `.fixed` both click the correct point.
- **T-303: Add Pick Location**
  - **Files:** `MainViewModel` and `TargetCard`
  - **Done when:** a 3 s countdown captures the cursor position in CG space, and SC-7 passes.

## M4: Hotkeys and failsafes

- **T-401: Add `HotkeyProviding` and `CarbonHotkeyManager`**
  - **Files:** `Core/Hotkeys/`
  - **Done when:**
    - Hotkeys are registered with `RegisterEventHotKey`, with context passed through `userData`.
    - All hotkeys are unregistered in `deinit`.
- **T-402: Wire up the F6 toggle**
  - **Files:** `MainViewModel`
  - **Done when:** SC-2 passes.
- **T-403: Add the scoped ESC emergency stop**
  - **Files:** `MainViewModel`
  - **Done when:**
    - ESC is registered only while clicking is active, and is unregistered on every stop path.
    - SC-3 passes.
- **T-404: Add `FailsafeMonitor`**
  - **Files:** `Core/Safety/FailsafeMonitor.swift`
  - **Done when:**
    - The corner check (≤ 2 px) and the own-window check both work.
    - SC-9 and SC-10 pass.

## M5: UI and persistence

- **T-501: Add `MainViewModel`**
  - **Files:** `Features/Main/MainViewModel.swift`
  - **Done when:**
    - Dependencies are injected.
    - The counter is sampled at 10–20 Hz while running.
    - The stop reason is shown.
- **T-502: Add the cards and `MainView`**
  - **Files:** `Features/Main/` and `Features/Components/`
  - **Done when:**
    - The status, click type, interval and jitter, target and stop-condition cards work.
    - The hotkey hint is shown.
    - Start is disabled when permission is missing.
- **T-503: Add `SettingsStore`**
  - **Files:** `Services/SettingsStore.swift`
  - **Done when:**
    - Settings are stored as versioned JSON in `UserDefaults`.
    - The tests use their own `UserDefaults` suite.
    - SC-8 passes.
- **T-504: Add `MenuBarExtra`**
  - **Files:** `Features/MenuBar/` and `AutoClickerApp`
  - **Done when:** the menu bar extra shows the status and offers Start/Stop.
- **T-505: Verify click types manually**
  - **Done when:** SC-4 and SC-5 pass.

## M7: Configurable hotkey and app assets

M7 is done before M6 (see [ROADMAP.md](ROADMAP.md)).

- **T-701: Persist the start/stop shortcut**
  - **Files:** `Hotkey` (Codable, display name with modifier glyphs), `Services/SettingsStore.swift`
  - **Done when:**
    - The settings schema is version 2 and stores the shortcut alongside the click configuration.
    - Version 1 data migrates with the shortcut defaulting to F6, and the migration is unit-tested.
- **T-702: Add the shortcut recorder**
  - **Files:** `Core/Hotkeys/ShortcutRecording.swift`, `Core/Hotkeys/LocalShortcutRecorder.swift`, a validation type, `MockShortcutRecorder`
  - **Done when:**
    - The validation rules from SPEC §3.3 are unit-tested (F-keys alone, ⌘/⌥/⌃ required otherwise, Shift-only and Esc rejected).
    - The local monitor exists only while recording.
- **T-703: Wire the configurable shortcut into the app**
  - **Files:** `MainViewModel`, `HotkeyHint` (or a new card), `MenuBarPresentation`
  - **Done when:**
    - Change…, Reset and cancel work; a shortcut that cannot be registered keeps the previous one and shows a warning.
    - The hint and the menu bar extra show the current shortcut.
    - ViewModel tests with `MockHotkeyProvider` and `MockShortcutRecorder` pass.
- **T-704: Add the app icon and accent color**
  - **Files:** `AutoClicker/Assets.xcassets`, a generator script outside the app target
  - **Done when:**
    - `AppIcon` has every macOS size (16–1024 px at 1x/2x), drawn without SF Symbols (their license forbids use in app icons).
    - `AccentColor` matches the icon.
    - The icon shows in the Dock, Finder and the app switcher.

## M8: Modifier clicks

M8 is done before M6 (see [ROADMAP.md](ROADMAP.md)).

- **T-801: Add `ClickModifiers` and settings schema v3**
  - **Files:** `Core/Engine/ClickModifiers.swift`, `ClickConfiguration`, `Services/SettingsStore.swift`
  - **Done when:**
    - `ClickModifiers` is a `Sendable`, `Codable` option set of shift, control, option and command, with a stable, readable JSON form.
    - `ClickConfiguration` has `modifiers` (default none), and settings schema version 3 stores it. Versions 1 and 2 migrate with no modifiers, and the migrations are unit-tested.
- **T-802: Post modifier flags**
  - **Files:** `EventPosting`, `CGEventPoster`, `ClickEngine`, `MockEventPoster`
  - **Done when:**
    - Every mouse-down/up event of every click type carries exactly the configured `CGEventFlags`, and no key events are posted (ADR-009). The pure event builder is unit-tested for each modifier and combination.
    - The engine passes the run's modifiers on every click, checked with `MockEventPoster`.
- **T-803: Add the "Hold" row and show the modifiers**
  - **Files:** `ClickTypeCard` (or a new component), `MenuBarPresentation`
  - **Done when:**
    - Four toggles (⇧ ⌃ ⌥ ⌘) edit `configuration.modifiers` and are locked while clicking. ⌃ with a left or double click shows the context-menu hint.
    - The menu bar status names the modifiers (for example "⇧-Left click"), and that text is unit-tested.

## M9: Tabbed window

M9 is done before M6 (see [ROADMAP.md](ROADMAP.md)).

- **T-901: Add the tab shell**
  - **Files:** `Features/Main/MainView.swift` (the `TabView` container), `App/AutoClickerApp.swift` (window size and commands), `Features/Tabs/WindowMetrics.swift` (read only)
  - **Done when:**
    - The four tabs are shown with the native `TabView` and `sidebarAdaptable` where available, and the window always opens on Main.
    - The toolbar Start/Stop and the permission banner are present on every tab.
    - "About AutoClicker" selects About, ⌘, selects Shortcuts, and Help has Report a Bug….
    - The window cannot shrink below `WindowMetrics.defaultContentSize`.
- **T-902: Add the Main and About tabs**
  - **Files:** `Features/Tabs/MainTab.swift`, `Features/Tabs/AboutTab.swift`, a pure bug-report URL builder, `.github/ISSUE_TEMPLATE/bug_report.yml`
  - **Done when:**
    - Main shows the seven items from SPEC §3.5 in order, and its settings summary text is unit-tested.
    - About shows the app info and permission state, and the bug report URL builder is unit-tested (prefilled versions only).
- **T-903: Add the Click and Shortcuts tabs**
  - **Files:** `Features/Tabs/ClickTab.swift`, `Features/Tabs/ShortcutsTab.swift`, the existing card components they replace
  - **Done when:**
    - Both tabs are grouped `Form`s with the sections from SPEC §3.5, reusing the existing clamping editors.
    - The Click tab fits the default window size without scrolling, or `WindowMetrics` is widened to a two-column layout.

## M6: Hardening and release

- **T-601: Profile with Instruments**
  - **Done when:** SC-6 and SC-11 are verified, and the results are noted in `CHANGELOG.md`.
- **T-602: Pass over all success criteria**
  - **Done when:** SC-1 to SC-11 are each checked, with their results recorded.
- **T-603: Document the Release build and notarization**
  - **Files:** `README.md`, `scripts/build-release.sh`
  - **Done when:** the steps for Developer ID signing, notarization and stapling are documented.
- **T-604: Tag 0.1.0**
  - **Files:** `CHANGELOG.md`
  - **Done when:** the `0.1.0` entry is written and a git tag is created.
