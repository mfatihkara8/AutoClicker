<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/icon-dark.png">
  <img src="docs/images/icon-light.png" alt="AutoClicker icon" width="128" height="128">
</picture>

# AutoClicker

**A precise, lightweight auto clicker for macOS.**<br>
Native Swift and SwiftUI · Apple Silicon and Intel · Free and open source

[![Download for macOS](https://img.shields.io/badge/Download_for_macOS-2F6BFF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/mfatihkara8/AutoClicker/releases/latest)

[![Latest release](https://img.shields.io/github/v/release/mfatihkara8/AutoClicker?color=2F6BFF)](https://github.com/mfatihkara8/AutoClicker/releases/latest)
[![macOS 14 or later](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple&logoColor=white)](#install)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![MIT license](https://img.shields.io/github/license/mfatihkara8/AutoClicker?color=lightgrey)](LICENSE)
[![Vibe coded with Claude Code](https://img.shields.io/badge/vibe_coded_with-Claude_Code-D97757?logo=claude&logoColor=white)](#how-it-was-built)

<img src="docs/images/main-tab.png" alt="The AutoClicker window on its Main tab, with the active profile, the click counter and the Start button" width="720">

</div>

## Features
- **Every click type:** left, right, middle and true double clicks.
- **Precise timing:**
  - Set the interval in hours, minutes, seconds and milliseconds, down to 1 ms, with optional random jitter.
  - Clicks follow a drift-free schedule, so the rate stays accurate over long runs.
- **Click where you want:** at the pointer, or at a fixed point on any display. **Pick Location** captures the point for you.
- **Click sequences:** click up to 50 points in turn, each after its own delay, then start over. Add points with a 3-second pick countdown.
- **Random offset:** let each click on a fixed point or sequence point land up to 200 pt away, so clicking looks less mechanical.
- **Profiles:** save your settings under a name, and switch between them from the **Profiles** tab or the menu bar.
- **Stop on your terms:** after a number of clicks, after a set time, or never.
- **Modifier clicks:** hold <kbd>⇧</kbd> <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>⌘</kbd> while clicking, for example ⌘-click links to open them in new tabs.
- **Works from any app:** <kbd>F6</kbd> starts and stops clicking wherever you are, and you can record your own shortcut instead.
- **Built-in safety:**
  - <kbd>Esc</kbd> stops clicking at once.
  - Moving the pointer into a screen corner also stops it.
  - AutoClicker never clicks its own window.
- **Stays out of the way:**
  - A menu bar extra keeps clicking after you close the window.
  - AutoClicker uses no CPU while idle.
- **Private:**
  - Accessibility is the only permission it needs.
  - It makes no network requests and collects no data.

<p align="center">
  <img src="docs/images/click-tab.png" alt="The Click tab with a three-point click sequence, a random offset, the click type, interval and stop condition" width="720">
</p>

## Install
1. Download **AutoClicker-x.y.z.dmg** from the [latest release](https://github.com/mfatihkara8/AutoClicker/releases/latest).
2. Open the DMG and drag **AutoClicker** onto **Applications**.
3. Open AutoClicker from Applications. The first time, macOS shows a warning, because the app is signed by an independent developer but [not notarized](#faq) by Apple:
   1. Close the warning. Don't move the app to the Trash.
   2. Go to **System Settings → Privacy & Security**.
   3. Scroll down to **Security**, click **Open Anyway** next to the message about AutoClicker, and confirm.
4. Grant **Accessibility** permission, which is needed to post clicks:
   1. Click **Request Access** in the app's banner, then **Open System Settings** in the dialog.
   2. Turn on **AutoClicker** under **Privacy & Security → Accessibility**.
   3. The banner disappears on its own, and you're ready to click.

**Requirements:** macOS 14 Sonoma or later, on Apple Silicon or Intel.

<details>
<summary>Verify the download (optional)</summary>
<br>

Compare the DMG's SHA-256 with the one in the release notes:

```sh
shasum -a 256 ~/Downloads/AutoClicker-*.dmg
```

</details>

## Usage
1. On the **Click** tab, choose the click type, interval, target and when to stop.
2. Press <kbd>F6</kbd> to start. Press it again to stop.

**Click several points:**
1. Under **Target**, choose **Sequence** and click **Edit Points…**.
2. Click **Add Point**, and move the pointer to the spot within 3 seconds.
3. Repeat for each point, and set each point's delay.

AutoClicker clicks the points in order, then starts over.

**Save a setup:** on the **Profiles** tab, click **Save as New Profile…**. Apply it later from that tab, or from the **Profiles** submenu of the menu bar extra.

| Shortcut | What it does |
|---|---|
| <kbd>F6</kbd> | Starts or stops clicking from any app. You can record your own on the **Shortcuts** tab. |
| <kbd>Esc</kbd> | Stops clicking at once. AutoClicker only takes Esc while it is clicking, so other apps keep their Esc key. |
| Screen corner | Moving the pointer into any corner of a screen stops clicking. |
| <kbd>⌘</kbd> <kbd>,</kbd> | Opens the **Shortcuts** tab. |

The menu bar extra shows the status and the click count, and has Start/Stop and your profiles. AutoClicker keeps running there after you close its window. To quit, choose **Quit AutoClicker** in the menu bar extra, or press <kbd>⌘</kbd> <kbd>Q</kbd> while the window is active.

<p align="center">
  <img src="docs/images/profiles-tab.png" alt="The Profiles tab, with the current settings, Save Changes, Save as New Profile, and three saved profiles" width="49%">
  <img src="docs/images/sequence-sheet.png" alt="The Edit Points sheet, with three points, their X and Y positions and delays, and Add Point" width="49%">
</p>

## FAQ

<details>
<summary><b>macOS says AutoClicker can't be opened</b></summary>
<br>

Apple notarizes apps only for members of its paid Developer Program, and AutoClicker isn't notarized. The app is still code-signed, so macOS knows who built it and that it hasn't been changed.

To open it once:
1. Go to **System Settings → Privacy & Security**.
2. Scroll down to **Security** and click **Open Anyway** next to the message about AutoClicker.

After that, it opens normally. On macOS 15 and later, Control-clicking the app and choosing **Open** no longer skips this step.

</details>

<details>
<summary><b>Why does it need Accessibility permission?</b></summary>
<br>

macOS lets an app post mouse clicks to other apps only if it has Accessibility permission. AutoClicker needs nothing else:
- Its shortcuts use the system hotkey API, so there's no **Input Monitoring**.
- It never records the screen.
- It makes no network requests.

</details>

<details>
<summary><b>Clicking doesn't start, or the permission banner won't go away</b></summary>
<br>

1. Make sure **AutoClicker** is turned on in **System Settings → Privacy & Security → Accessibility**.
2. If it's on but the banner stays, remove it from the list with the **−** button, then click **Request Access** in the app again.
3. Still stuck? Reset the permission in Terminal, then grant it again:

   ```sh
   tccutil reset Accessibility com.mfatihkara8.AutoClicker
   ```

</details>

<details>
<summary><b>F6 does nothing</b></summary>
<br>

On most Mac keyboards, the top row controls system features by default. You have three options:
- Hold <kbd>fn</kbd> (<kbd>🌐</kbd>) while pressing <kbd>F6</kbd>.
- Turn on **Use F1, F2, etc. keys as standard function keys** in **System Settings → Keyboard → Keyboard Shortcuts → Function Keys**.
- Record another shortcut on the **Shortcuts** tab.

If another app already uses the shortcut, AutoClicker shows a warning.

</details>

<details>
<summary><b>How do I stop it if something goes wrong?</b></summary>
<br>

Any of these stops clicking:
- Press <kbd>Esc</kbd>.
- Press your start/stop shortcut.
- Move the pointer into any corner of the screen.

AutoClicker also skips clicks that would land on its own window, so you can always reach the Stop button.

</details>

<details>
<summary><b>How do I update?</b></summary>
<br>

1. Download the new DMG from the [latest release](https://github.com/mfatihkara8/AutoClicker/releases/latest).
2. Quit AutoClicker.
3. Drag the new app onto **Applications** and replace the old one.

Your settings and profiles carry over. macOS may ask you to confirm the first launch again with **Open Anyway**.

</details>

<details>
<summary><b>Why isn't it on the Mac App Store?</b></summary>
<br>

Mac App Store apps must run in the App Sandbox, and a sandboxed app can't post clicks to other apps.

</details>

## Roadmap
- **Done in 0.2.0:** saved profiles, click sequences with a delay per point, and a random offset around the target.
- **Planned:** recording and playing back mouse and keyboard macros.

The details are in [docs/ROADMAP.md](docs/ROADMAP.md).

## Build from source
You need Xcode 27 or later.

```sh
git clone https://github.com/mfatihkara8/AutoClicker.git
cd AutoClicker
open AutoClicker.xcodeproj
```

In Xcode, select your own team under **Signing & Capabilities**, then press <kbd>⌘</kbd> <kbd>R</kbd>. Any Apple ID works. A fixed team keeps the Accessibility permission across rebuilds.

From the terminal:

```sh
# Build
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData build

# Unit tests (Swift Testing)
xcodebuild -project AutoClicker.xcodeproj -scheme AutoClicker -destination 'platform=macOS' -derivedDataPath build/DerivedData -only-testing:AutoClickerTests test

# Format and lint
swift format -i -r AutoClicker AutoClickerTests AutoClickerUITests
swift format lint -r --strict AutoClicker AutoClickerTests AutoClickerUITests
```

Release builds, performance checks and notarization are covered in [docs/RELEASING.md](docs/RELEASING.md).

## Contributing
- **Bug reports:** choose **Help → Report a Bug…** in the app, or [open an issue](https://github.com/mfatihkara8/AutoClicker/issues/new?template=bug_report.yml).
- **Pull requests:** welcome. Start with the docs below.

| Document | What's in it |
|---|---|
| [SPEC.md](docs/SPEC.md) | The requirements (the source of truth) |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, folders, types and threading |
| [RULES.md](docs/RULES.md) | Coding, testing and git conventions |
| [DECISIONS.md](docs/DECISIONS.md) | Why things are the way they are |
| [GOALS.md](docs/GOALS.md) | Success criteria |
| [ROADMAP.md](docs/ROADMAP.md), [TASKS.md](docs/TASKS.md) | Milestones and tasks |
| [RELEASING.md](docs/RELEASING.md) | Building, checking and publishing a release |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |

## How it was built
AutoClicker is **vibe coded**. The app's code, tests and documentation were written by Claude in [Claude Code](https://claude.com/claude-code). The author described what the app should do and steered every step.

- **The author:**
  - set the goals and sketched the interface,
  - answered the design questions and made the product decisions,
  - tested the app by hand and approved each release.
- **Claude:**
  - turned the goals into a specification, decision records and milestones,
  - built each milestone with several agents working in parallel,
  - reviewed and merged their work.
- **Checks:**
  - Every change passes the unit tests and a strict linter before it is merged.
  - Each release is measured against the [success criteria](docs/GOALS.md#success-criteria), such as click accuracy and CPU use.

The commits that Claude wrote carry a `Co-Authored-By: Claude` line, so the history shows who did what.

## License
[MIT](LICENSE) © 2026 Mehmet Fatih Kara
