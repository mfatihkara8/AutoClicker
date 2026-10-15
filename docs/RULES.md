# Rules

These rules apply to everyone who contributes to this repository, human or AI.

## Language
- **Everything in the repository is in English.** This includes:
  - code,
  - identifiers,
  - comments,
  - UI strings,
  - log messages,
  - commit messages,
  - branch names,
  - documentation.
- UI strings go through `String(localized:)` or `LocalizedStringKey`. This keeps localization possible later, even though only English ships in Phase 1.

## Swift style
- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/):
  - Types and protocols use `UpperCamelCase`. Everything else uses `lowerCamelCase`.
  - A protocol that describes a capability ends in `-ing` or `-able`, for example `EventPosting` or `PermissionChecking`.
- **One primary type per file**, and the file is named after the type.
- **Formatting:** use `swift format`, which ships with Xcode 16+, with the repo's `.swift-format` config. Code must pass `swift format lint` before committing.
- **Access control:**
  - Use the narrowest level that works.
  - Make classes `final` unless they are designed to be subclassed.
- **No force unwraps or `try!`** in production code. They are allowed only in tests and in `Preview` code.
- **Comments:** comments explain *why*, not *what*. Public engine APIs get a `///` doc comment.

## Architecture (MVVM)
- **Layers:** Views call the ViewModel, which calls the engine and services. The layout is in [ARCHITECTURE.md](ARCHITECTURE.md).
- **Views:** views hold no logic beyond formatting, and never touch `Core` directly.
- **Engine:**
  - `Core/` never imports SwiftUI and never references a ViewModel.
  - System APIs (`CGEvent`, Carbon, AX) are accessed only through their adapter types: `CGEventPoster`, `CarbonHotkeyManager` and `AccessibilityPermissionChecker`.
- **Dependencies:**
  - Inject dependencies through initializers.
  - Do not use singletons, and do not use `static shared`.
- **Coordinates:** all coordinate conversion goes through `ScreenGeometry` ([ADR-006](DECISIONS.md#adr-006-coordinates-stored-in-cg-global-space)).

## Concurrency
- **Strict concurrency:** Swift 6 language mode, with strict concurrency set to Complete. Do not suppress warnings.
- **Main-actor types:** UI state types are `@MainActor`.
- **Click loop:**
  - The click loop runs only on the engine's serial queue.
  - Never block the main thread, and never hop to the main actor on every click.
- **Shared state:** values that cross isolation boundaries are `Sendable` value types. Shared mutable state uses `OSAllocatedUnfairLock`.
- **`@unchecked Sendable`:** needs a comment explaining why it is safe.

## Resources and performance
- **Cleanup:** every timer, hotkey registration and polling task has a clear owner, and is cancelled on stop and in `deinit`.
- **Closures:** stored closures and timer handlers capture `[weak self]`.
- **Idle CPU:** must be about 0%. Nothing polls unless it is needed; permission polling happens only while permission is missing and the window is visible.
- **Dependencies:** no third-party dependencies without a new ADR.

## Testing
- **Coverage:**
  - Engine, scheduler, stop conditions, geometry and settings code needs unit tests written with Swift Testing (`import Testing`, `@Test`, `#expect`). UI tests use XCTest (`AutoClickerUITests`).
  - System-facing code is tested through protocol mocks in `AutoClickerTests/Mocks`.
- **Isolation:** tests never post real events, never register real hotkeys and never use `UserDefaults.standard`.
- **Bug fixes:** a bug fix comes with a test that reproduces the bug, whenever that is feasible.

## Git
- **Branches:**
  - `main` is always buildable.
  - Feature branches are named `feat/<task-id>-short-name`, for example `feat/T-204-click-scheduler`.
- **Commits:**
  - Use [Conventional Commits](https://www.conventionalcommits.org/), for example `feat(engine): add deadline-based ClickScheduler (T-204)`.
  - The types are `feat`, `fix`, `refactor`, `test`, `docs`, `chore` and `perf`.
  - Keep commits small and focused. Reference the task ID when there is one.
- **Never commit:**
  - `xcuserdata/`,
  - `DerivedData/`,
  - signing certificates,
  - secrets.

## Documentation
- **When a task is finished:**
  - Tick it in `TODO.md`.
  - If it changed behavior, add an entry under `[Unreleased]` in `CHANGELOG.md`.
- **When a requirement changes:** update [SPEC.md](SPEC.md) in the same change.
- **When a fixed decision changes:** add a new ADR in [DECISIONS.md](DECISIONS.md). Never rewrite an old one.
- **When the structure changes:** update [ARCHITECTURE.md](ARCHITECTURE.md) whenever types or folders are added, moved or renamed.
