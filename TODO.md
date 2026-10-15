# TODO

This is the live progress tracker. Task details are in [docs/TASKS.md](docs/TASKS.md).

- Work on the **Now** section from top to bottom.
- When a task is finished, tick it and move it to **Done**. If it changed behavior, also update [CHANGELOG.md](CHANGELOG.md).

**Current milestone:** M1, Permissions

## Now
Milestone M0 is complete. Next up is M1.
- [ ] T-101: Add `PermissionChecking` and `AccessibilityPermissionChecker`
- [ ] T-102: Add `PermissionManager`
- [ ] T-103: Add `PermissionBanner`. Also confirm the T-002 follow-up: the Accessibility grant survives a rebuild.

## Next
- M2: Click engine (T-201 to T-205)
- M3: Targeting and coordinates (T-301 to T-303)

## Done
- [x] T-002: Signing and capabilities set (fixed Team `9J8JPZCUTL`, Sandbox off, Hardened Runtime on)
- [x] T-003: Folder skeleton created; `ContentView` renamed to `MainView`
- [x] T-004: Test targets and `AutoClickerTests/Mocks/` folder in place
- [x] T-005: `.swift-format` added, lint clean
- [x] T-001: Xcode project created (Xcode 27; Swift 6, macOS 14.0, Swift Testing)
- [x] T-006: Build and test commands recorded in CLAUDE.md and README.md
- [x] Project docs: SPEC, GOALS, ARCHITECTURE, ROADMAP, TASKS, RULES and DECISIONS
- [x] git repository initialized
