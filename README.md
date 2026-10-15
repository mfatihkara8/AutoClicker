# AutoClicker

A lightweight, native macOS auto clicker built with Swift 6 and SwiftUI. It runs on Apple Silicon and Intel.

> **Status:** pre-alpha. The project docs are in place and implementation starts with milestone M0. See [TODO.md](TODO.md).

## Features (Phase 1)
- **Click types:** left, right, middle and true double clicks.
- **Interval:** set as hours, minutes, seconds and milliseconds, with optional random jitter. Clicks follow a drift-free schedule.
- **Target:** the current cursor position or fixed X/Y coordinates. Fixed coordinates work on any display, and "Pick Location" captures them for you.
- **Stop conditions:** never stop, stop after N clicks, or stop after a set duration.
- **Global hotkeys:** **F6** starts and stops clicking. **ESC** is an emergency stop.
- **Failsafes:** moving the cursor into a screen corner stops clicking, and the app never clicks its own window.
- **Window and menu bar:** a compact window, plus an optional menu bar extra.
- **Settings:** saved between launches.

## Requirements
- macOS 14 Sonoma or later.
- Xcode 16 or later, to build from source.
- **Accessibility** permission, which is needed to post clicks. No other permission is needed.

## Granting permission
1. Launch the app and click **Open System Settings** on the banner.
2. Go to *Privacy & Security → Accessibility* and turn on **AutoClicker**.
3. The banner disappears on its own within about 2 seconds.

If you change the signing identity, the permission can get stuck. Reset it with:

```sh
tccutil reset Accessibility <bundle-id>
```

## Building
Open `AutoClicker.xcodeproj` in Xcode and press **⌘R**. To build from the terminal instead:

```sh
# Build
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData build

# Unit tests (Swift Testing)
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:AutoClickerTests test

# A single test: -only-testing:<Target>/<Suite>/<testFunction()>
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:'AutoClickerTests/AutoClickerTests/example()' test
```

The app is **not sandboxed** and is distributed outside the Mac App Store; see [ADR-001](docs/DECISIONS.md).

## Documentation

| Document | Purpose |
|---|---|
| [docs/SPEC.md](docs/SPEC.md) | Requirements (the source of truth) |
| [docs/GOALS.md](docs/GOALS.md) | Goals, non-goals and success criteria |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, folder layout, types and flows |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Architecture decision records |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones and future phases |
| [docs/TASKS.md](docs/TASKS.md) | Task breakdown with completion criteria |
| [docs/RULES.md](docs/RULES.md) | Coding and contribution rules |
| [TODO.md](TODO.md) | Live progress tracker |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |
