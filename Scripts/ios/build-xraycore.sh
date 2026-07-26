#!/usr/bin/env bash
#
# Builds XrayCore.xcframework — Xray-core compiled for iOS device + simulator
# via gomobile. This is the ONLY native dependency of the iOS app: no
# tun2socks, no sing-box. Xray's own `tun` inbound terminates the packets it
# gets from NetworkExtension.
#
# Usage: Scripts/ios/build-xraycore.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRIDGE="$ROOT/ios/XrayBridge"
OUT_DIR="$ROOT/ios/Frameworks"
OUT="$OUT_DIR/XrayCore.xcframework"

command -v go >/dev/null || { echo "error: Go toolchain not found (brew install go)"; exit 1; }
command -v xcodebuild >/dev/null || { echo "error: Xcode not found"; exit 1; }

export PATH="$PATH:$(go env GOPATH)/bin"

if ! command -v gomobile >/dev/null; then
    echo "==> installing gomobile"
    go install golang.org/x/mobile/cmd/gomobile@latest
    go install golang.org/x/mobile/cmd/gobind@latest
fi

echo "==> resolving Go modules"
cd "$BRIDGE"
go mod download

echo "==> gomobile init"
gomobile init

echo "==> building XrayCore.xcframework (device + simulator, arm64)"
mkdir -p "$OUT_DIR"
rm -rf "$OUT"
gomobile bind \
    -target=ios,iossimulator \
    -iosversion=16.0 \
    -o "$OUT" \
    -ldflags="-s -w" \
    -trimpath \
    .

echo
echo "==> done: $OUT"
du -sh "$OUT"
