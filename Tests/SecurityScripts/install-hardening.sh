#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALLER="${ROOT}/Scripts/install-daemon.sh"
PROCESS="${ROOT}/Sources/XrayClient/Core/XrayProcess.swift"
PACKAGE="${ROOT}/Scripts/package-app.sh"

bash -n "${INSTALLER}" "${PACKAGE}" "${ROOT}/Scripts/run-app.sh"

require() {
  grep -Fq -- "$1" "$2" || { echo "missing security invariant: $1 ($2)" >&2; exit 1; }
}
reject() {
  if grep -Fq -- "$1" "$2"; then
    echo "forbidden security pattern: $1 ($2)" >&2
    exit 1
  fi
}

require 'codesign --verify --deep --strict' "${INSTALLER}"
require 'payload.sha256' "${INSTALLER}"
require 'must not be a symlink' "${INSTALLER}"
require 'staged hash mismatch' "${INSTALLER}"
require 'installed hash mismatch' "${INSTALLER}"
require 'production helper installation requires a Team-ID-signed app' "${INSTALLER}"
require 'VeilDevelopmentBuild' "${ROOT}/Scripts/run-app.sh"
require 'codesign --verify --strict "${STAGE}/VeilHelper"' "${INSTALLER}"
require '/usr/bin/shasum -a 256 VeilHelper tun2socks install-daemon.sh uninstall-daemon.sh' "${PACKAGE}"
require 'codesign --verify --deep --strict "${APP_DIR}"' "${PACKAGE}"
reject '/usr/local/bin' "${PROCESS}"
reject '/opt/homebrew/bin' "${PROCESS}"
reject 'codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true' "${PACKAGE}"

echo "security script invariants passed"
