# AutoClicker

A lightweight, native macOS auto clicker built with Swift 6 and SwiftUI. It runs on Apple Silicon and Intel.

> **Status:** 0.1.0, the first release. It completes Phase 1, the core auto clicker. Macro recording and playback are planned for a later phase; see [docs/ROADMAP.md](docs/ROADMAP.md).

## Features
- **Click types:** left, right, middle and true double clicks.
- **Modifier clicks:** hold any combination of ⇧ Shift, ⌃ Control, ⌥ Option and ⌘ Command while clicking, for example ⌘-click to open links in new tabs. The keys are set on each click, so none can get stuck.
- **Interval:** set as hours, minutes, seconds and milliseconds, with optional random jitter. Clicks follow a drift-free schedule.
- **Target:** the current cursor position or fixed X/Y coordinates. Fixed coordinates work on any display, and "Pick Location" captures them for you.
- **Stop conditions:** never stop, stop after N clicks, or stop after a set duration.
- **Start/stop shortcut:** **F6** by default, and it works in every app. You can record your own: F1–F20 alone, or any key with ⌘, ⌥ or ⌃. **Reset** brings back F6.
- **Emergency stop:** **ESC** stops clicking at once. It is only taken while clicking, so other apps keep their Esc key.
- **Failsafes:** moving the cursor into a screen corner stops clicking, and the app never clicks its own window.
- **Window:** one window with **Main**, **Click**, **Shortcuts** and **About** tabs. A toolbar button moves the tabs into a sidebar (macOS 15 and later), and every tab shows the status and a Start/Stop button in the toolbar.
- **Menu bar:** an always-visible menu bar extra with the status, Start/Stop and Reset Counter. Clicking goes on after the window is closed.
- **Report a Bug…:** in the About tab and the Help menu. It opens a GitHub issue form prefilled with the app and macOS versions, and nothing else.
- **Settings:** saved between launches.

## Requirements
- macOS 14 Sonoma or later.
- **Accessibility** permission, which is needed to post clicks. No other permission is needed.
- To build from source: Xcode 27 or later. The project file uses the Xcode 27 format.

## Install
1. Download `AutoClicker-<version>.dmg` from [GitHub Releases](https://github.com/mfatihkara8/AutoClicker/releases).
2. Open the DMG and drag **AutoClicker** onto **Applications**.

To check the download, compare its SHA-256 with the one in the release notes:

```sh
shasum -a 256 ~/Downloads/AutoClicker-<version>.dmg
```

### First launch
macOS warns you the first time you open AutoClicker, because the app is signed by an independent developer but not notarized by Apple. To open it:

1. Open AutoClicker from Applications once, and dismiss the warning. Don't choose **Move to Trash**.
2. Go to *System Settings → Privacy & Security*, scroll down to *Security*, click **Open Anyway** next to the message about AutoClicker, and confirm.
3. Grant Accessibility permission; see [Granting permission](#granting-permission).

On macOS 15 and later, Control-clicking the app and choosing **Open** no longer skips the warning, so step 2 is needed.

## Granting permission
1. Launch the app and click **Open System Settings** on the banner.
2. Go to *Privacy & Security → Accessibility* and turn on **AutoClicker**.
3. The banner disappears on its own within about 2 seconds.

If you change the signing identity, the permission can get stuck. Reset it with:

```sh
tccutil reset Accessibility com.mfatihkara8.AutoClicker
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

## Release build
`scripts/build-release.sh` builds the Release configuration and packages it for a GitHub Release:

```sh
# Signed, verified build packaged as build/Release/AutoClicker-<version>.dmg
scripts/build-release.sh

# The same build for leaks and Instruments, with no DMG
scripts/build-release.sh --profiling
```

The release build:
- is universal (Apple Silicon and Intel) and signed with the team's **Apple Development** certificate, with the Hardened Runtime and a secure timestamp. Your keychain needs that certificate. The app is never ad-hoc signed, because that would reset the Accessibility permission on every build.
- leaves out the `get-task-allow` entitlement, so no debugger can attach to the shipped app.
- verifies the signature and prints the Gatekeeper assessment. Gatekeeper rejects the app until it is notarized, so the script shows that result but does not stop on it.
- writes `build/Release/AutoClicker-<version>.dmg`, holding the app and a link to Applications. The version is `MARKETING_VERSION` from the project. The DMG is signed with the same certificate, and the script prints its SHA-256 for the release notes.

`--profiling` keeps `get-task-allow`, so `leaks` and Instruments can attach, and writes to `build/Release/Profiling`. The script prints the app's path. Never ship this build.

Any `NAME=value` argument is passed to `xcodebuild` as a build setting.

### Notarization (requires a paid Apple Developer Program membership)
**0.1.0 is not notarized.** With a membership, these steps remove the first-launch warning:

1. Create a **Developer ID Application** certificate: *Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application*.
2. Build with it. The script signs the DMG with the same certificate as the app:

   ```sh
   scripts/build-release.sh CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application"
   ```

3. Store the notary credentials in your keychain, once. It asks for an app-specific password, which you create at [account.apple.com](https://account.apple.com):

   ```sh
   xcrun notarytool store-credentials AutoClicker-notary --apple-id <your-apple-id> --team-id 9J8JPZCUTL
   ```

4. Submit the DMG and wait for the result:

   ```sh
   xcrun notarytool submit build/Release/AutoClicker-<version>.dmg --keychain-profile AutoClicker-notary --wait
   ```

   If it is rejected, `xcrun notarytool log <submission-id> --keychain-profile AutoClicker-notary` explains why.

5. Staple the ticket to the DMG, so Gatekeeper can check it offline:

   ```sh
   xcrun stapler staple build/Release/AutoClicker-<version>.dmg
   ```

6. Check the result:

   ```sh
   xcrun stapler validate build/Release/AutoClicker-<version>.dmg
   spctl -a -t open --context context:primary-signature -vv build/Release/AutoClicker-<version>.dmg
   ```

   `spctl` should print `accepted` and `source=Notarized Developer ID`.

Stapling changes the DMG, so take its SHA-256 afterwards. The Developer ID certificate also changes the app's signature, so users of an earlier build have to grant Accessibility again.

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

## License
[MIT](LICENSE)
