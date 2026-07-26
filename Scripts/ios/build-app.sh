#!/usr/bin/env bash
#
# Builds the iOS app. Defaults to the simulator, which needs no signing;
# pass `device` to build for a real iPhone (requires a Team ID).
#
# Usage:
#   Scripts/ios/build-app.sh                       # simulator, Debug
#   Scripts/ios/build-app.sh simulator Release
#   Scripts/ios/build-app.sh device Release TEAMID
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT/ios/Veil.xcodeproj"
FRAMEWORK="$ROOT/ios/Frameworks/XrayCore.xcframework"

TARGET_KIND="${1:-simulator}"
CONFIGURATION="${2:-Debug}"
TEAM_ID="${3:-}"

if [[ ! -d "$FRAMEWORK" ]]; then
    echo "error: $FRAMEWORK is missing."
    echo "       Run Scripts/ios/build-xraycore.sh first — the app cannot link without it."
    exit 1
fi

case "$TARGET_KIND" in
    simulator)
        DESTINATION='generic/platform=iOS Simulator'
        SDK=iphonesimulator
        EXTRA=()
        ;;
    device)
        DESTINATION='generic/platform=iOS'
        SDK=iphoneos
        if [[ -n "$TEAM_ID" ]]; then
            EXTRA=("DEVELOPMENT_TEAM=$TEAM_ID")
        else
            echo "note: no Team ID given — building without code signing."
            echo "      The result will not install on a device; pass your Team ID as arg 3."
            EXTRA=(CODE_SIGNING_ALLOWED=NO)
        fi
        ;;
    *)
        echo "usage: $0 [simulator|device] [Debug|Release] [TEAM_ID]"
        exit 1
        ;;
esac

echo "==> building Veil ($TARGET_KIND, $CONFIGURATION)"
xcodebuild \
    -project "$PROJECT" \
    -scheme Veil \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -derivedDataPath "$ROOT/ios/build" \
    ${EXTRA[@]+"${EXTRA[@]}"} \
    build

echo
echo "==> done: $ROOT/ios/build/Build/Products/$CONFIGURATION-$SDK/Veil.app"
