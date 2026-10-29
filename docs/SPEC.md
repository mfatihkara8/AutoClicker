# Specification — AutoClicker (Phase 1)

A lightweight, high-performance, native macOS AutoClicker for Apple Silicon and Intel. Macro recording and playback come in a later phase (see [ROADMAP.md](ROADMAP.md)).

This document is the source of truth for requirements. The reasoning behind each fixed decision is in [DECISIONS.md](DECISIONS.md).

## 1. Fixed technical decisions

These are settled. Changing one requires a new ADR in [DECISIONS.md](DECISIONS.md).

- **Language and frameworks:**
  - Swift 6 with strict concurrency.
  - SwiftUI with Observation (`@Observable`).
  - Deployment target **macOS 14+**.
- **System APIs:**
  - Core Graphics (`CGEvent`) to post clicks.
  - Accessibility (`ApplicationServices`) for permissions.
  - Carbon (`RegisterEventHotKey`) for global hotkeys.
- **Project:** an Xcode project, not SwiftPM. The bundle ID is fixed, e.g. `com.<name>.AutoClicker`.
- **App Sandbox is OFF.** A sandboxed app cannot post `CGEvent` clicks, so the app is distributed outside the Mac App Store.
- **Signing:**
  - Every build, Debug included, is signed with a fixed Development Team.
  - Ad-hoc signing changes the signature on every build, which invalidates the Accessibility permission.
  - If the permission gets stuck, reset it with `tccutil reset Accessibility <bundle-id>`.
- **UI:**
  - Modern macOS look in a compact single window.
  - Settings are laid out as cards, with no tabs.
  - An optional `MenuBarExtra`.

## 2. Permissions

### Accessibility (required to post clicks)
- **Check at launch:** use `AXIsProcessTrustedWithOptions`. The prompt option is `true` only when the user presses the request button.
- **Live updates:** there is no official notification when this permission changes.
  - While permission is missing and the window is visible, poll `AXIsProcessTrusted()` about once a second.
  - Stop polling as soon as permission is granted.
- **Missing permission:**
  - Show a warning banner.
  - The banner's "Open System Settings" button opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
  - The Start control is disabled.

### Input Monitoring (not required)
Hotkeys are registered through Carbon. `CGEvent.tapCreate` and `NSEvent.addGlobalMonitorForEvents` are **not** used, so Input Monitoring is never needed.

## 3. Phase 1 requirements

### 3.1 `PermissionManager`
Implements the flow in section 2. It is `@Observable` and `@MainActor`.

### 3.2 `ClickEngine` (fully independent of the UI)

**Click types:**

| Type | Events |
|---|---|
| Left | `.leftMouseDown` / `.leftMouseUp` |
| Right | `.rightMouseDown` / `.rightMouseUp` |
| Middle | `.otherMouseDown` / `.otherMouseUp` with `mouseButton: .center` |
| Double | Two down/up pairs. The second pair sets `kCGMouseEventClickState = 2`, otherwise the system does not register a double click. |

**Event posting:** events are created with `CGEventSource(stateID: .hidSystemState)` and posted to `.cghidEventTap`.

**Modifier keys** ([ADR-009](DECISIONS.md#adr-009-modifier-clicks-via-event-flags-only)):
- The user can hold any combination of ⇧ Shift, ⌃ Control, ⌥ Option and ⌘ Command for every click, with every click type (for example ⇧⌘-click). The default is none.
- The modifiers are set as flags on each posted mouse event. No separate key-down/key-up events are posted, so a modifier can never get stuck.
- The click type card has a "Hold" row with one toggle per modifier, locked while clicking like the other settings. Choosing ⌃ with a left or double click shows the hint "⌃-click opens the context menu in most apps." The menu bar status names the modifiers (for example "⇧-Left click").
- The modifiers are persisted with the click configuration (settings schema version 3; older data migrates with no modifiers).

**Interval:**
- Entered as hours, minutes, seconds and milliseconds.
- Minimum 1 ms.
- Optional random jitter of ± N ms.

**Target position:**
- *Current cursor location:* read with `CGEvent(source: nil)?.location`.
- *Fixed X/Y:* either entered manually or captured with "Pick Location". Pick Location runs a 3-second countdown, then stores the cursor position.
- *Coordinate system:* all coordinates are stored in the **CG global coordinate space**, with the origin at the top left of the main display.
  - `NSEvent.mouseLocation` has its origin at the bottom left. If it is used, convert it using the main screen's height.
  - Positions must be correct on multi-monitor setups.

**Stop condition:** run forever, stop after N clicks, or stop after duration T.

**Timing:**
- A `sleep(interval)` loop drifts over time, so don't use one.
- Schedule each click against an absolute deadline instead, on a dedicated serial queue.
- Use `DispatchSourceTimer` with low leeway, or a `ContinuousClock` deadline.

### 3.3 Global hotkey (`HotkeyManager`)
- Register a default **F6** start/stop hotkey with Carbon `RegisterEventHotKey`. It needs no permission and costs no CPU.
- **Configurable start/stop hotkey** ([ADR-008](DECISIONS.md#adr-008-user-configurable-startstop-hotkey-recorded-with-a-scoped-local-key-monitor)):
  - The hotkey card shows the current shortcut with **Change…** and **Reset** (back to F6) buttons.
  - **Change…** enters recording mode ("Press a key combination… Esc to cancel"). The next key-down in the main window is captured with a local `NSEvent` monitor that exists only while recording.
  - Accepted: F1–F20 alone, or any other key with at least one of ⌘, ⌥ or ⌃. Shift alone is rejected with a hint. Esc cancels recording and can never be chosen.
  - If the new shortcut cannot be registered, the previous one stays active and a "This shortcut is in use" warning is shown.
  - The shortcut is persisted with the other settings, and the hotkey hint and the menu bar extra show the current shortcut.
  - The ESC emergency stop is not configurable.
- The Carbon C callback cannot capture context, so pass context through its `userData` pointer.
- Unregister with `UnregisterEventHotKey` on stop and in `deinit`.

### 3.4 Failsafes
- **ESC emergency stop:**
  - ESC is registered as a Carbon hotkey **only while clicking is active**, and unregistered when clicking stops.
  - This way it never swallows ESC in other apps.
- **Corner failsafe:** before each click, if the cursor is within 2 px of a screen corner, the engine stops.
- **Own-window protection:** if the target point is inside one of the app's own windows, the click is skipped and a warning is shown.

### 3.5 User interface
- **Window and tabs:**
  - One main window with four tabs: **Main**, **Click**, **Shortcuts** and **About**. It always opens on Main; the last tab is not remembered.
  - Tabs use the native SwiftUI `TabView`, centered at the top of the window, with no custom styling. On macOS 26 and later this is the system's Liquid Glass tab bar.
  - The window opens with the tabs at the top. One toolbar button at the leading edge switches the tabs to a sidebar; pressing it again (or collapsing the sidebar) moves them back to the top. The last choice is remembered. Sidebar mode needs macOS 15 or later; on macOS 14 the tabs stay at the top with the standard look and the button is hidden.
  - The toolbar shows no window title and has no empty hoverable or clickable regions.
  - Every tab fits the default window size (760×520) without scrolling. The window can grow but cannot shrink below that size. The Click tab uses two columns (Click and Interval on the left, Target and Stop on the right), because one column at 560 wide was too tall.
- **On every tab:** at the trailing end of the toolbar, a non-interactive status indicator (gray dot and "Idle", or green dot and "Active"; no click count) followed by a round, icon-only Start/Stop button (▶︎ while idle, ■ while clicking) with a tooltip naming the shortcut, for example "Start (F6)". The Accessibility permission banner is at the top while permission is missing.
- **Main tab**, top to bottom:
  1. Active/Inactive status.
  2. The big total click counter with Reset.
  3. The big Start/Stop button.
  4. A one-line summary of the current settings, for example "⇧-Left click · 100 ms · Cursor · Never stops".
  5. The last stop reason.
  6. Warnings, such as the own-window warning.
  7. The shortcut hint, for example "F6 start/stop · Esc stop".
- **Click tab:** a grouped `Form` (System Settings style) with sections for the click type and held modifiers, interval and jitter, target with Pick Location, and the stop condition. Locked while clicking.
- **Shortcuts tab:** a grouped `Form` with the start/stop shortcut (Change…, Reset) and the fixed Esc emergency stop.
- **About tab:** the app icon, name and version, the Accessibility permission state (with "Open System Settings" when missing), the GitHub link, the MIT license, and **Report a Bug…**.
- **Report a Bug…** opens the repository's new-issue page with the bug report form, prefilled with the app version and macOS version and nothing else. The repository has a `.github/ISSUE_TEMPLATE/bug_report.yml` issue form. While the repository is private, only its collaborators can use the link.
- **Menus:** "About AutoClicker" in the app menu selects the About tab, Settings… (⌘,) selects the Shortcuts tab, and the Help menu has Report a Bug….
- **Menu bar extra:** always visible, with the status and Start/Stop (unchanged).

### 3.6 Persistence
- All settings are persisted with `UserDefaults`.
- `@AppStorage` does not work inside an `@Observable` class. Use a dedicated `SettingsStore`, or write to `UserDefaults` in `didSet`.

## 4. Architecture rules

- **MVVM:**
  - Views call an `@Observable @MainActor` ViewModel, which calls the engine and services.
  - The engine knows nothing about SwiftUI or the ViewModel. It is decoupled through the `EventPosting` (mocked in tests), `HotkeyProviding` and `PermissionChecking` protocols.
- **Concurrency:**
  - The click loop runs off the main thread.
  - Follow Swift 6 `Sendable` rules. Any `@unchecked Sendable` needs a comment explaining why it is safe.
- **UI updates:**
  - Do not hop to the `MainActor` on every click.
  - The click counter is guarded by `OSAllocatedUnfairLock`. `Synchronization.Atomic` requires macOS 15, so it is not used.
  - The UI reads the counter at 10–20 Hz.
- **Resource management:**
  - Cancel timers, hotkeys and permission polling when they stop.
  - Use `[weak self]` in closures and avoid retain cycles.
  - Idle CPU should be about 0%.

Detailed conventions are in [RULES.md](RULES.md). The type layout is in [ARCHITECTURE.md](ARCHITECTURE.md).

## 5. Out of scope for Phase 1
- Macro recording and playback.
- Profiles.
- Multi-point or sequential clicking.
- Mouse movement simulation.
- Auto-update.

## 6. Acceptance criteria
The authoritative list is in [GOALS.md § Success criteria](GOALS.md#success-criteria).
