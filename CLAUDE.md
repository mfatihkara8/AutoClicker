# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

This is a native macOS AutoClicker built with Swift 6, SwiftUI and `@Observable`, targeting macOS 14+. The Xcode project was created with Xcode 27; Phase 1 (M1–M5, M7–M9) is implemented. Check `TODO.md` for the current task.

## Commands

```sh
# Build
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData build

# Unit tests (Swift Testing)
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:AutoClickerTests test

# Signed Release build + DMG in build/Release (--profiling keeps get-task-allow for leaks/Instruments, no DMG)
scripts/build-release.sh

# Format and lint (config: .swift-format, 4 spaces, 120 columns); lint must be clean before committing
swift format -i -r AutoClicker AutoClickerTests AutoClickerUITests
swift format lint -r --strict AutoClicker AutoClickerTests AutoClickerUITests

# A single test: -only-testing:<Target>/<Suite>/<testFunction()>
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:'AutoClickerTests/AutoClickerTests/example()' test
```

- Build output goes to `build/DerivedData`, which is git-ignored.
- `AutoClickerUITests` (XCTest) launches the real app, so leave it out of quick runs.
- **Project settings:**
  - Settings live in `AutoClicker.xcodeproj/project.pbxproj`. `Info.plist` is generated, and there is no entitlements file.
  - Source folders are file-system-synchronized: a new `.swift` file under `AutoClicker/` is picked up automatically, with no pbxproj edit needed.
  - Every file in those folders becomes part of the target. Never put placeholder files (`.gitkeep`, READMEs) there: they get copied into the app bundle and collide at build time. Empty folders from `docs/ARCHITECTURE.md` exist only on disk until their first `.swift` file arrives.
  - Swift 6 language mode is on. The default actor isolation was removed on purpose, so types are nonisolated unless marked `@MainActor`.

## Where things are

| File | Read it when |
|---|---|
| `docs/SPEC.md` | You need the requirements. It is the source of truth. |
| `docs/ARCHITECTURE.md` | You need the layers, folder layout, type responsibilities, or the flows across threads and actors. |
| `docs/RULES.md` | You need coding, concurrency, testing, git or docs conventions. Follow them. |
| `docs/DECISIONS.md` | You need the reason behind a fixed choice. To change one, add a new ADR instead of editing an old one. |
| `docs/GOALS.md` | You need the success criteria (SC-1…SC-11) that each milestone is checked against. |
| `docs/ROADMAP.md`, `docs/TASKS.md` | You need the milestones (M0–M9) or the tasks (`T-xxx`), each with its "Done when" criteria. |
| `docs/RELEASING.md` | You build, check or publish a release, measure performance, or set up notarization. |
| `TODO.md` | You need to know what to work on now. |

## Workflow

**Session notes:** `SESSION_NOTES.md` is a private, git-ignored log.
- At the start of a session, read its "Where we left off" section and its environment facts first. If the file is missing, this is a fresh clone; ask the user where things stand.
- When the user ends a session:
  - Update "Where we left off".
  - Add a dated entry at the top of "Session log", covering what was done, the decisions made and the gotchas.

1. Pick the next task from the **Now** section of `TODO.md`. Read its entry in `docs/TASKS.md`.
2. Implement it on a `feat/<task-id>-short-name` branch, using Conventional Commits that reference the task ID.
3. When it's done:
   - Tick the task in `TODO.md`.
   - If behavior changed, add an entry under `[Unreleased]` in `CHANGELOG.md`.
   - If types or folders changed, update `ARCHITECTURE.md`.

## Non-negotiables

- **English only:** all code, identifiers, comments, UI strings, commits and docs are in English, even when the user writes in Turkish.
- **Sandbox and signing:**
  - App Sandbox stays **off**, because `CGEvent` posting needs it off.
  - Builds are signed with a fixed Development Team. Otherwise the Accessibility grant resets on every build. To reset it manually: `tccutil reset Accessibility <bundle-id>`.
- **Hotkeys:** use Carbon `RegisterEventHotKey` only. Never use event taps or `NSEvent` global monitors, because they would require Input Monitoring permission. The one exception is the shortcut recorder: it may use an `NSEvent` *local* monitor, installed only while recording ([ADR-008](docs/DECISIONS.md)).
- **Engine isolation:**
  - The engine (`Core/`) never imports SwiftUI.
  - System APIs are only reached through the `EventPosting`, `HotkeyProviding` and `PermissionChecking` adapters.
- **Counter and coordinates:**
  - The click counter uses `OSAllocatedUnfairLock`. Don't use `Synchronization.Atomic`, which needs macOS 15.
  - The UI samples the counter at 10–20 Hz.
  - Coordinates are CG global (top-left origin). Convert only in `ScreenGeometry`.
