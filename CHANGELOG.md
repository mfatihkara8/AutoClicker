# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
