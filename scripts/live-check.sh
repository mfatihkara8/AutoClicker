#!/usr/bin/env bash
#
# An end-to-end check with REAL events: builds the profiling app, opens a click target window, and lets the app add
# three sequence points with the real Add Point countdown, apply a profile from its menu bar extra, and click the
# target 12 times with ⌘ held. Then compares what the target received with what the app was asked to do.
#
# Usage (from anywhere; the script works from the repository root):
#
#     scripts/live-check.sh               # build with scripts/build-release.sh --profiling, then check
#     scripts/live-check.sh --no-build    # reuse the last profiling build
#     scripts/live-check.sh --app=PATH    # check another build with DIAGNOSTICS, such as the Debug app
#
# It moves the pointer and clicks on screen for about 20 seconds: keep your hands off the mouse and keyboard until it
# prints the results. Esc stops the clicks. The pointer is put back where it was at the end.
#
# The clicks, and pressing the app's own buttons and menu bar extra, need the Accessibility grant of the app signed
# with the team certificate (the same bundle ID as the installed app). The check never prompts for it; without it,
# Add Point and the profile step fall back to the view model and the clicks are skipped, so the check fails. The app
# is launched through LaunchServices (`open --env`), not as a child of this shell: macOS asks the process responsible
# for a child (the terminal) about Accessibility, so a direct launch reports the app as not trusted.
#
# The app's settings live in a throwaway suite. The window frame and status item keys macOS writes into the app's
# real preferences are saved before and restored after. Everything else is written under build/LiveCheck.

set -euo pipefail

readonly lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
readonly bundle_id=com.mfatihkara8.AutoClicker
# A path, not the bare bundle ID: `defaults` would otherwise pick a leftover sandbox container's copy.
readonly preferences="$HOME/Library/Preferences/$bundle_id"
readonly timeout_seconds=90

usage() {
    sed -n 's/^#     //p' "${BASH_SOURCE[0]}"
}

build=true
app=""
for arg in "$@"; do
    case "$arg" in
        --no-build) build=false ;;
        --app=*)
            app="${arg#--app=}"
            build=false
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $arg" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if [[ -n "$app" ]]; then
    # Absolute, before the `cd` below, so a path relative to the caller's directory keeps working.
    [[ -d "$app" ]] || {
        echo "error: $app is not an app bundle" >&2
        exit 1
    }
    app="$(cd "$app" && pwd)"
fi

# Every path below is relative to the repository root.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ -z "$app" ]]; then
    app="$PWD/build/Release/Profiling/DerivedData/Build/Products/Release/AutoClicker.app"
fi
readonly app
readonly work="$PWD/build/LiveCheck"
readonly target_bin="$work/click-target"
readonly frame_file="$work/target-frame.json"
readonly clicks_file="$work/clicks.jsonl"
readonly result_file="$work/live-check-result.json"
readonly app_log="$work/app.log"
readonly preferences_backup="$work/preferences-backup.plist"

step() {
    printf '\n==> %s\n' "$1"
}

target_pid=""
preferences_saved=false
cleanup() {
    if [[ -n "$target_pid" ]] && kill -0 "$target_pid" 2> /dev/null; then
        # SIGTERM makes the target put the pointer back before it quits.
        kill "$target_pid" 2> /dev/null || true
        wait "$target_pid" 2> /dev/null || true
    fi
    pkill -f "$app/Contents/MacOS/AutoClicker" 2> /dev/null || true
    if $preferences_saved; then
        defaults import "$preferences" "$preferences_backup" || echo "warning: could not restore $preferences" >&2
    fi
    if [[ -d "$app" ]]; then
        "$lsregister" -u "$app" || echo "warning: could not unregister $app from LaunchServices" >&2
    fi
}
trap cleanup EXIT

if $build; then
    step "Building the profiling app (Release + DIAGNOSTICS)"
    scripts/build-release.sh --profiling
fi
[[ -x "$app/Contents/MacOS/AutoClicker" ]] || {
    echo "error: $app does not exist; run without --no-build" >&2
    exit 1
}

step "Compiling the click target"
mkdir -p "$work"
swiftc -O -swift-version 6 scripts/click-target.swift -o "$target_bin"
rm -f "$frame_file" "$clicks_file" "$result_file" "$app_log"

step "Saving the app's real preferences"
if defaults export "$preferences" "$preferences_backup" 2> /dev/null; then
    preferences_saved=true
else
    # No preferences yet: restore to an empty domain afterwards.
    printf '{}' | plutil -convert xml1 -o "$preferences_backup" - && preferences_saved=true
fi

step "Opening the click target"
"$target_bin" record "$frame_file" "$clicks_file" "$timeout_seconds" &
target_pid=$!
for _ in {1..50}; do
    [[ -s "$frame_file" ]] && break
    sleep 0.1
done
[[ -s "$frame_file" ]] || {
    echo "error: the click target did not write $frame_file" >&2
    exit 1
}
cat "$frame_file"
echo

step "Running the live check (hands off the mouse; Esc stops the clicks)"
# -n: a new instance even if the installed app is running; -W: wait for it to quit.
open -n -W \
    --env "AUTOCLICKER_LIVE_CHECK=$frame_file" \
    --env "AUTOCLICKER_LIVE_CHECK_RESULT=$result_file" \
    --stderr "$app_log" --stdout "$app_log" \
    "$app" --args -ApplePersistenceIgnoreState YES &
open_pid=$!
for ((elapsed = 0; elapsed < timeout_seconds; elapsed++)); do
    kill -0 "$open_pid" 2> /dev/null || break
    sleep 1
done
if kill -0 "$open_pid" 2> /dev/null; then
    echo "error: the app did not finish within ${timeout_seconds}s; quitting it" >&2
    pkill -f "$app/Contents/MacOS/AutoClicker" 2> /dev/null || true
fi
wait "$open_pid" 2> /dev/null || true
grep '\[diagnostics\]' "$app_log" || true

# Lets the target record any click still in flight, then puts the pointer back.
sleep 0.5
kill "$target_pid" 2> /dev/null || true
wait "$target_pid" 2> /dev/null || true
target_pid=""

step "Results"
[[ -s "$result_file" ]] || {
    echo "error: the app wrote no result to $result_file" >&2
    exit 1
}
echo "Result: $result_file"
echo "Clicks: $clicks_file"
"$target_bin" verify "$clicks_file" "$result_file"
