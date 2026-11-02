# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-02

Phase 2: click sequences, a random position offset and profiles.

Checked on an Apple M5 Pro Mac with macOS 27.0.1:
- **SC-12 to SC-14** pass as acceptance tests: a 3-point sequence clicks in order with exact counts, every offset click lands inside its radius, and a saved profile survives a relaunch and restores every setting.
- **SC-15:** a 60 s sequence run with a 20 pt offset used 3.3% CPU on average, with 0% idle and no leaks (dry run without posting events).
- An end-to-end check with real events (`scripts/live-check.sh`) passed: Add Point through the real sheet, the menu bar Profiles submenu, and 12 of 12 clicks in sequence order with ⌘ held and the offset inside 8 pt.

### Added
- Click sequences: the Target section's new **Sequence** mode clicks up to 50 points in order, each after its own delay, then starts over. **Edit Points…** opens a sheet to add points with the 3-second Pick Location countdown, edit X, Y and the delay, reorder and remove them. Click type, modifiers, jitter and the stop condition apply to every point, and timing stays drift-free.
- Random position offset: each click on a fixed point or a sequence point can land up to 0–200 pt away, drawn uniformly from a disk. It is off by default and not used with the current cursor.
- Profiles: a new **Profiles** tab saves the click settings under a name (up to 50), applies, renames and deletes them, and saves changes to the active profile. The menu bar extra has a **Profiles** submenu, and the Main tab shows the active profile and whether it was modified. The start/stop shortcut stays global.
- Settings schema version 4, which stores sequences, the offset and the profiles. Older settings migrate automatically.

### Fixed
- Sidebar mode no longer clips the sidebar and the tab content: the window widens by the sidebar width (200 pt).
- The Click tab no longer scrolls by a few points when the permission banner is shown.

### Changed
- The Main tab summary names a sequence and the offset, for example "Left click · Sequence of 3 points ± 5 pt · Never stops". Start is disabled for an empty sequence, with a warning.

## [0.1.0] - 2026-10-29

The first release: the Phase 1 auto clicker. It is signed with an Apple Development certificate but not notarized, so macOS warns on the first launch; the README's *First launch* section explains how to open it.

Checked on an Apple M5 Pro Mac with macOS 27.0.1:
- **SC-6:** a 60 s run at a 10 ms interval posted exactly 6,000 clicks and used 3.6% CPU on average (6% for one second as it started and stopped). Memory stayed flat at about 118 MB.
- **SC-11:** 0% CPU while idle, and `leaks` found no leaks after 10 start/stop cycles.
- **SC-2 and SC-8**, plus the custom shortcut and modifier clicks, were checked by hand on 2026-10-29. SC-1, SC-3, SC-4, SC-5, SC-9 and SC-10 passed in the manual pass of 2026-10-16.
- **SC-7** (a fixed target on a second display) is untested, since no second display was available. The coordinate conversion for several displays is covered by unit tests.

### Added
- Click types: left, right, middle and true double clicks (click state 2), posted through Core Graphics.
- Interval in hours, minutes, seconds and milliseconds (1 ms minimum) with optional ± jitter, on a drift-free deadline schedule. Jitter never accumulates, and missed ticks are skipped rather than burst-fired.
- Targets: the current cursor, or fixed X/Y coordinates on any display. Pick Location captures a point after a 3 s countdown.
- Stop conditions: never, after N clicks, or after a set duration.
- Modifier clicks: hold any combination of ⇧ Shift, ⌃ Control, ⌥ Option and ⌘ Command for every click, for example ⌘-click to open links in new tabs. The keys are set as event flags, so none can get stuck.
- Start/stop shortcut: F6 by default, working from any app. Change… records a new one (F1–F20 alone, or any key with ⌘, ⌥ or ⌃), and Reset goes back to F6. A shortcut that cannot be registered keeps the previous one, with a warning.
- Emergency stop: Esc stops clicking, and is registered only while clicking.
- Failsafes: moving the cursor into a screen corner stops clicking, clicks aimed at the app's own window are skipped with a warning, and clicking stops if Accessibility permission is revoked.
- Tabbed window with Main, Click, Shortcuts and About tabs on the native macOS tab bar. One toolbar button moves the tabs into a sidebar and back (macOS 15 and later). Every tab's toolbar has an Idle/Active status dot and a ▶︎/■ Start/Stop button, and nothing scrolls at the default size.
- Menu bar extra, always visible: status and live count, Start/Stop, Reset Counter, Show AutoClicker Window (⌘0) and Quit. Clicking goes on after the window is closed.
- Accessibility permission banner with Open System Settings and Request Access, hidden about 1 s after permission is granted.
- About tab and Help menu with Report a Bug…, which opens a GitHub issue form prefilled with the app and macOS versions.
- Settings are saved automatically as versioned JSON, 0.5 s after the last change and on quit. Missing or corrupt data falls back to the defaults.
- App icon with light, dark and tinted appearances on macOS 26 and later (the light icon on macOS 14 and 15), and a matching blue accent color.
- `scripts/build-release.sh` builds the signed, universal Release app and its DMG. `scripts/measure-performance.sh` samples a running app's CPU and memory, then checks it for leaks.

[Unreleased]: https://github.com/mfatihkara8/AutoClicker/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/mfatihkara8/AutoClicker/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mfatihkara8/AutoClicker/releases/tag/v0.1.0
