#!/usr/bin/env bash
#
# Opens the Debug app with sample data for README screenshots, without touching the user's settings or clicking
# anything.
#
# Usage (from anywhere; the script works from the repository root):
#
#     scripts/showcase.sh             # build, then open the app with three profiles, a sequence and a filled counter
#     scripts/showcase.sh --no-build  # reuse the last build
#
# The app runs with AUTOCLICKER_SHOWCASE set, which only DIAGNOSTICS builds understand. It uses a throwaway settings
# suite, posts no events, fakes Accessibility trust and registers no hotkeys, so the installed app keeps F6. Take the
# screenshots (⌘⇧4, then Space, then click the window), then quit it with ⌘Q; the script then unregisters the build from
# LaunchServices and removes its window frame and saved state. The build uses the diagnostics bundle ID of
# scripts/diagnose-ui.sh.

set -euo pipefail

readonly lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
readonly bundle_id=com.mfatihkara8.AutoClicker.Diagnostics

usage() {
    sed -n 's/^#     //p' "${BASH_SOURCE[0]}"
}

build=true
case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    --no-build) build=false ;;
    "") ;;
    *)
        echo "error: unknown option: $1" >&2
        usage >&2
        exit 64
        ;;
esac

# Every path below is relative to the repository root.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly derived_data=build/Diagnostics/DerivedData
readonly app="$derived_data/Build/Products/Debug/AutoClicker.app"

cleanup() {
    if [[ -d "$app" ]]; then
        "$lsregister" -u "$PWD/$app" || echo "warning: could not unregister $app from LaunchServices" >&2
    fi
    defaults delete "$bundle_id" > /dev/null 2>&1 || true
    rm -rf "$HOME/Library/Saved Application State/$bundle_id.savedState"
}
trap cleanup EXIT

if $build; then
    printf '\n==> Building the Debug app (DIAGNOSTICS) into %s\n' "$derived_data"
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
fi
[[ -d "$app" ]] || {
    echo "error: $app does not exist; run without --no-build" >&2
    exit 1
}

printf '\n==> Opening the showcase; quit the app with ⌘Q when the screenshots are done\n'
# The binary itself rather than `open`, so the environment reaches the app and this script waits for it. Trust is faked,
# so the terminal's Accessibility grant does not matter here. The README is in English, so numbers are formatted for
# en_US ("1,250", not "1.250") whatever the Mac's region is.
AUTOCLICKER_SHOWCASE=1 "$app/Contents/MacOS/AutoClicker" -ApplePersistenceIgnoreState YES \
    -AppleLocale en_US -AppleLanguages '(en)'
