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
- Thread-safe click counter, multi-monitor coordinate conversion with screen-corner detection, and Carbon global hotkeys (not wired to the UI yet).
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
