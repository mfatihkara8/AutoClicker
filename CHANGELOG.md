# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/mfatihkara8/AutoClicker/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mfatihkara8/AutoClicker/releases/tag/v0.1.0
