# TODO

This is the live progress tracker. Task details are in [docs/TASKS.md](docs/TASKS.md).

- Work on the **Now** section from top to bottom.
- When a task is finished, tick it and move it to **Done**. If it changed behavior, also update [CHANGELOG.md](CHANGELOG.md).

**Current milestone:** M2, Click engine (wave 2 of the parallel plan)

## Now
Wave 2 (parallel worktree agents):
- [ ] T-204 → T-205 → T-302: `ClickScheduler`, `ClickEngine`, target resolution
- [ ] T-404 + T-503: `FailsafeMonitor`, `SettingsStore`
- [ ] Manual: SC-1 (banner hides within 2 s of the grant) and the T-002 follow-up (the grant survives a rebuild)

## Next
- Wave 3: T-501 `MainViewModel`, failsafe wiring, T-402 F6, T-403 scoped ESC, T-303 Pick Location
- Wave 4: T-502 cards and `MainView`, T-504 `MenuBarExtra`

## Done
- [x] T-401: `Hotkey`, `HotkeyProviding`, `CarbonHotkeyManager`, `MockHotkeyProvider`
- [x] T-301: `ScreenGeometry` (AppKit ↔ CG conversion, corners, cursor)
- [x] T-203: `ClickCounter` (`OSAllocatedUnfairLock`)
- [x] T-202: `EventPosting`, `CGEventPoster`, `MockEventPoster`
- [x] T-201: `ClickType`, `ClickTarget`, `ClickInterval`, `StopCondition`, `ClickConfiguration`
- [x] T-103: `PermissionBanner` wired into `MainView` (SC-1 still to be checked manually)
- [x] T-102: `PermissionManager` with visibility-driven 1 s polling
- [x] T-101: `PermissionChecking` and `AccessibilityPermissionChecker`
- [x] T-002: Signing and capabilities set (fixed Team `9J8JPZCUTL`, Sandbox off, Hardened Runtime on)
- [x] T-003: Folder skeleton created; `ContentView` renamed to `MainView`
- [x] T-004: Test targets and `AutoClickerTests/Mocks/` folder in place
- [x] T-005: `.swift-format` added, lint clean
- [x] T-001: Xcode project created (Xcode 27; Swift 6, macOS 14.0, Swift Testing)
- [x] T-006: Build and test commands recorded in CLAUDE.md and README.md
- [x] Project docs: SPEC, GOALS, ARCHITECTURE, ROADMAP, TASKS, RULES and DECISIONS
- [x] git repository initialized
