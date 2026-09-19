#!/usr/bin/env bash
# Downloads the Xray-core binary for macOS into Sources/XrayClient/Resources/.
# Detects CPU architecture (arm64 / x86_64) automatically; TARGET_ARCH
# overrides the detection so the Intel release can be cross-packaged on an
# arm64 runner.
set -euo pipefail

# shellcheck source=Scripts/core-lock.sh
source "$(cd "$(dirname "$0")" && pwd)/core-lock.sh"

REPO="XTLS/Xray-core"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/Sources/XrayClient/Resources"
mkdir -p "$DEST_DIR"

ARCH="${TARGET_ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64)  ASSET="Xray-macos-arm64-v8a.zip" ;;
  x86_64) ASSET="Xray-macos-64.zip" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Pinned release from Scripts/cores.lock, or the latest one when unpinned.
TAG="$(resolve_tag "$REPO" xray "$ARCH")" || {
  echo "Could not resolve an Xray-core release tag." >&2
  exit 1
}
echo "Xray-core release: ${TAG}"

URL="https://github.com/$REPO/releases/download/${TAG}/${ASSET}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading ${ASSET}..."
curl -fsSL "${URL}" -o "$TMP/xray.zip"

verify_asset xray "$ARCH" "$TMP/xray.zip" || exit 1
record_asset xray "$ARCH" "${TAG}" "$TMP/xray.zip"

echo "Extracting..."
unzip -o -q "$TMP/xray.zip" -d "$TMP/extracted"

cp "$TMP/extracted/xray" "$DEST_DIR/xray"
chmod +x "$DEST_DIR/xray"

# Remove the quarantine attribute so Gatekeeper allows execution.
xattr -dr com.apple.quarantine "$DEST_DIR/xray" 2>/dev/null || true

echo "Installed xray -> $DEST_DIR/xray"
"$DEST_DIR/xray" version || true
