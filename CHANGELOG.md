# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Tabbed main window with Main, Click, Shortcuts and About tabs, using the native macOS tab bar (Liquid Glass on macOS 26). One toolbar button switches the tabs to a sidebar and back (macOS 15 and later), and the choice is remembered. Every tab's toolbar has an Idle/Active status dot and a round ▶︎/■ Start/Stop button, nothing scrolls at the default size, and the Click and Shortcuts tabs use the System Settings grouped style.
- About tab and Help menu with Report a Bug…, which opens a GitHub issue form prefilled with the app and macOS versions. About AutoClicker and Settings… (⌘,) open the matching tabs.
- Modifier clicks: hold any combination of ⇧ Shift, ⌃ Control, ⌥ Option and ⌘ Command for every click (for example ⌘-click to open links in new tabs). Set as event flags, so a key can never get stuck. The menu bar shows the modified click while running.
- Configurable start/stop shortcut: Change… records a new key combination (F1–F20 alone, or with ⌘/⌥/⌃), Reset goes back to F6, Esc cancels. The shortcut is saved and shown in the window and the menu bar; a shortcut that cannot be registered keeps the previous one with a warning.
- App icon with light, dark and tinted appearances on macOS 26 and later (light icon on macOS 14 and 15), and a matching blue accent color.
- Accessibility permission detection: a banner with "Open System Settings" and "Request Access" buttons, shown while permission is missing and hidden automatically about 1 s after it is granted.
- Click configuration model: click type (left, right, middle, double), interval in h/m/s/ms with a 1 ms minimum and ± jitter, current-cursor or fixed target, and stop conditions (never, after N clicks, after a duration).
- Click event posting through Core Graphics, including middle clicks and real double clicks (click state 2).
- Click engine: deadline-based scheduling on a serial queue (no drift, jitter never accumulates, missed ticks are skipped rather than burst-fired), current-cursor and fixed targets, and stop conditions measured per run.
- Failsafes: the run stops when the cursor reaches a screen corner (≤ 2 px); clicks targeting the app's own windows are skipped.
- Settings persistence as versioned JSON in `UserDefaults`, falling back to defaults for missing, corrupt or unknown-version data.
- Card-based main window: status with a big Start/Stop button, click type, interval and jitter, target (current cursor, fixed X/Y, Pick Location), stop condition, and a hotkey hint. Settings are locked while clicking, and every field is clamped to a valid range.
- Menu bar extra, always visible: status and live count, Start/Stop, Reset Counter, Show AutoClicker Window (⌘0) and Quit. The app keeps running and clicking when its window is closed.
- Clicks targeting the app's own window are skipped with a "move the cursor outside" warning, and clicking resumes automatically; Pick Location uses a 3 s countdown; a warning is shown when F6 is taken by another app.
- Global hotkeys: F6 starts and stops clicking from any app; Esc stops clicking and is registered only while clicking is active.
- Clicking stops automatically if Accessibility permission is revoked while running.
- Settings are saved automatically (0.5 s after the last change, and on quit). The app keeps running when its window is closed.
- Thread-safe click counter, multi-monitor coordinate conversion and screen-corner detection.
- `.swift-format` configuration (4-space indent, 120 columns).
- Xcode project: Swift 6, macOS 14+, App Sandbox off, Hardened Runtime on, Swift Testing unit tests and XCTest UI tests.
- Project documentation:
  - specification,
  - goals,
  - architecture,
  - decision records,
  - roadmap,
  - tasks,
  - rules.
