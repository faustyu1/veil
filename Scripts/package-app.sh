#!/usr/bin/env bash
# Builds Veil and packages it into a macOS .app bundle, then zips it.
# Unlike run-app.sh this does not launch the app — it is meant for CI/release.
# Usage: Scripts/package-app.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

VERSION="${1:-$(cat "${ROOT}/VERSION")}"
CONFIG="release"
BUILD_NAME="XrayClient"      # SPM product (binary) name
APP_NAME="Veil"             # user-facing app + bundle name
APP_DIR="${ROOT}/${APP_NAME}.app"
DIST_DIR="${ROOT}/dist"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.app.zip"

echo "Building (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"

echo "Assembling ${APP_NAME}.app (version ${VERSION})..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Executable (renamed to the user-facing app name).
cp "${BIN_PATH}/${BUILD_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Bundled resources (the xray and sing-box binaries live in the SPM resource bundle).
BUNDLE="${BIN_PATH}/${BUILD_NAME}_${BUILD_NAME}.bundle"
if [ -d "${BUNDLE}" ]; then
  cp -R "${BUNDLE}" "${APP_DIR}/Contents/Resources/"
fi

# Privileged helper payload. Nothing here runs until the user installs it from
# Settings, which copies it to a root-owned directory after one admin prompt.
HELPER_DIR="${APP_DIR}/Contents/Library/VeilHelper"
mkdir -p "${HELPER_DIR}"
cp "${BIN_PATH}/VeilHelper" "${HELPER_DIR}/VeilHelper"
if [ -f "${ROOT}/Sources/XrayClient/Resources/tun2socks" ]; then
  cp "${ROOT}/Sources/XrayClient/Resources/tun2socks" "${HELPER_DIR}/tun2socks"
  cp "${ROOT}/Sources/XrayClient/Resources/tun2socks.sha256" "${HELPER_DIR}/tun2socks.sha256"
fi
cp "${ROOT}/Scripts/install-daemon.sh" "${HELPER_DIR}/install-daemon.sh"
cp "${ROOT}/Scripts/uninstall-daemon.sh" "${HELPER_DIR}/uninstall-daemon.sh"
chmod +x "${HELPER_DIR}"/* 2>/dev/null || true

# App icon, if present.
ICON_LINE=""
if [ -f "${ROOT}/Resources/AppIcon.icns" ]; then
  cp "${ROOT}/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
  ICON_LINE="  <key>CFBundleIconFile</key><string>AppIcon</string>"
fi

# Info.plist (LSUIElement=false so it shows in the Dock with a window)
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>dev.local.veil</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
${ICON_LINE}
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Veil uses the camera to scan server QR codes.</string>
  <key>VeilDevelopmentBuild</key><false/>
  <key>LSUIElement</key><false/>
</dict>
</plist>
PLIST

# Sign nested executables before hashing them: code signing changes Mach-O
# bytes. Hashing first would make every runtime/installer verification fail.
SIGN_IDENTITY="${VEIL_CODESIGN_IDENTITY:--}"
if [ "${SIGN_IDENTITY}" = "-" ]; then
  echo "WARNING: ad-hoc package cannot install the production privileged helper." >&2
  echo "Set VEIL_CODESIGN_IDENTITY to a Team-ID signing identity for TUN releases." >&2
fi
codesign --force --sign "${SIGN_IDENTITY}" "${HELPER_DIR}/VeilHelper"
codesign --force --sign "${SIGN_IDENTITY}" "${HELPER_DIR}/tun2socks"
ARCH="$(uname -m)"
while IFS= read -r core; do
  codesign --force --sign "${SIGN_IDENTITY}" "${core}"
  /usr/bin/shasum -a 256 "${core}" | /usr/bin/awk -v a="${ARCH}" '{print $1, a}' > "${core}.sha256"
done < <(find "${APP_DIR}/Contents/Resources" -type f \( -name xray -o -name sing-box \))
(
  cd "${HELPER_DIR}"
  /usr/bin/shasum -a 256 VeilHelper tun2socks install-daemon.sh uninstall-daemon.sh > payload.sha256
)

# Seal the resource hashes and nested signatures in the outer app signature.
codesign --force --sign "${SIGN_IDENTITY}" "${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}"

echo "Zipping..."
mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}"
# ditto preserves bundle structure + resource forks for a valid macOS app zip.
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "Done."
echo "App bundle: ${APP_DIR}"
echo "Zip:        ${ZIP_PATH}"
