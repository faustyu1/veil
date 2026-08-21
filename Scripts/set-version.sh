#!/usr/bin/env bash
# Sets the app version everywhere it is baked in.
#
# The VERSION file at the repository root is the single source of truth: this
# script writes it and propagates the number into the Xcode project, so a
# release tag, the macOS bundle and the iOS app always agree.
#
# Usage: Scripts/set-version.sh 1.3.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

VERSION="${1:-}"
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: Scripts/set-version.sh <major.minor.patch>   (got: '${VERSION}')" >&2
  exit 1
fi

echo "${VERSION}" > VERSION

PBXPROJ="ios/Veil.xcodeproj/project.pbxproj"
if [ -f "${PBXPROJ}" ]; then
  sed -i '' -E "s/MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+;/MARKETING_VERSION = ${VERSION};/g" "${PBXPROJ}"
fi

TARGETS="$(grep -c "MARKETING_VERSION = ${VERSION};" "${PBXPROJ}" || true)"
echo "Version set to ${VERSION}: VERSION, ${PBXPROJ} (${TARGETS} build configs)"
echo
echo "Next: commit, then tag v${VERSION} to publish the release."
