#!/usr/bin/env bash
#
# Builds the Debug app and lets it snapshot its own main window in every state worth checking, without Screen
# Recording permission and without touching the user's settings or clicking anything.
#
# Usage (from anywhere; the script works from the repository root):
#
#     scripts/diagnose-ui.sh                 # PNGs and layout-report.txt in build/Diagnostics/Snapshots
#     scripts/diagnose-ui.sh OUTPUT_DIR      # the same, into OUTPUT_DIR (emptied first)
#
# The app runs with AUTOCLICKER_SNAPSHOTS set, which only Debug and `scripts/build-release.sh --profiling` builds
# understand (the DIAGNOSTICS compilation condition). It then uses a throwaway settings suite, posts no events, fakes
# Accessibility trust, registers no hotkeys, writes one PNG per state and quits.
#
# The build uses its own bundle ID, so its window frame and saved state never mix with the installed app's, and it is
# unregistered from LaunchServices afterwards. Everything is written under build/, which is git-ignored.

set -euo pipefail

readonly lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
readonly bundle_id=com.mfatihkara8.AutoClicker.Diagnostics
readonly timeout_seconds=180

usage() {
    sed -n 's/^#     //p' "${BASH_SOURCE[0]}"
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
esac

# Every path below is relative to the repository root.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly derived_data=build/Diagnostics/DerivedData
readonly app="$derived_data/Build/Products/Debug/AutoClicker.app"
output="${1:-build/Diagnostics/Snapshots}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"

step() {
    printf '\n==> %s\n' "$1"
}

cleanup() {
    # Xcode registered the build with LaunchServices; left registered, it competes with the installed app.
    if [[ -d "$app" ]]; then
        "$lsregister" -u "$PWD/$app" || echo "warning: could not unregister $app from LaunchServices" >&2
    fi
    # The window frame and saved state of the diagnostics bundle ID, so the next run starts at the default size again.
    defaults delete "$bundle_id" > /dev/null 2>&1 || true
    rm -rf "$HOME/Library/Saved Application State/$bundle_id.savedState"
}
trap cleanup EXIT

step "Building the Debug app (DIAGNOSTICS) into $derived_data"
xcodebuild \
    -project AutoClicker.xcodeproj \
    -scheme AutoClicker \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived_data" \
    -quiet \
    PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
    ENABLE_CODE_COVERAGE=NO \
    CLANG_COVERAGE_MAPPING=NO \
    build
[[ -d "$app" ]] || {
    echo "error: the build succeeded but $app does not exist" >&2
    exit 1
}

step "Snapshotting into $output"
rm -f "$output"/*.png "$output/layout-report.txt"
# Run the binary itself rather than `open`, so the environment reaches the app and this script can wait for it. The
# argument keeps AppKit from restoring windows from an earlier run.
AUTOCLICKER_SNAPSHOTS="$output" "$app/Contents/MacOS/AutoClicker" -ApplePersistenceIgnoreState YES &
pid=$!
for ((elapsed = 0; elapsed < timeout_seconds; elapsed++)); do
    kill -0 "$pid" 2> /dev/null || break
    sleep 1
done
if kill -0 "$pid" 2> /dev/null; then
    echo "error: the app did not finish within ${timeout_seconds}s; killing it" >&2
    kill "$pid" 2> /dev/null || true
    wait "$pid" 2> /dev/null || true
    exit 1
fi
status=0
wait "$pid" || status=$?

step "Results"
shopt -s nullglob
pngs=("$output"/*.png)
for png in "${pngs[@]}"; do
    printf '%s  %s\n' "$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixel/ { printf "%s ", $2 }')" \
        "$(basename "$png")"
done
echo "${#pngs[@]} PNGs in $output"
echo "Layout report: $output/layout-report.txt"
if ((status != 0)); then
    echo "error: the app exited with status $status" >&2
    exit "$status"
fi
((${#pngs[@]})) || {
    echo "error: no PNGs were written" >&2
    exit 1
}
