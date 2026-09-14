#!/usr/bin/env bash
# core-lock.sh — shared version/checksum pinning for the bundled cores.
#
# Sourced by the fetch-*.sh scripts. The lockfile records, per core and
# architecture, the exact release the build expects and the SHA-256 of the
# release asset. A recorded hash that does not match aborts the build: Veil
# ships third-party binaries that run as root, so "whatever GitHub served
# today" is not an acceptable answer.
#
# Populate or refresh the lockfile with:
#     RECORD_HASHES=1 Scripts/fetch-xray.sh          # and the other two

LOCK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${LOCK_ROOT}/Scripts/cores.lock"

# lock_field <core> <arch> <field-index>
# Lockfile lines are: core arch version sha256
lock_field() {
  local core="$1" arch="$2" index="$3"
  [ -f "${LOCK_FILE}" ] || return 0
  awk -v c="${core}" -v a="${arch}" -v i="${index}" \
    '$1 == c && $2 == a { print $i; exit }' "${LOCK_FILE}"
}

lock_version() { lock_field "$1" "$2" 3; }
lock_sha256()  { lock_field "$1" "$2" 4; }

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# verify_asset <core> <arch> <file>
# Aborts when the lockfile pins a hash and the file does not match it.
verify_asset() {
  local core="$1" arch="$2" file="$3"
  local expected actual
  expected="$(lock_sha256 "${core}" "${arch}")"
  actual="$(sha256_of "${file}")"

  if [ -z "${expected}" ] || [ "${expected}" = "-" ]; then
    if [ "${RECORD_HASHES:-0}" != "1" ]; then
      echo "WARNING: ${core} (${arch}) is not pinned in Scripts/cores.lock." >&2
      echo "         Downloaded ${actual}" >&2
      echo "         Pin it with: RECORD_HASHES=1 $0" >&2
    fi
    return 0
  fi

  if [ "${expected}" != "${actual}" ]; then
    echo "ERROR: checksum mismatch for ${core} (${arch})." >&2
    echo "       expected ${expected}" >&2
    echo "       got      ${actual}" >&2
    return 1
  fi
  echo "Checksum OK (${actual})."
}

# record_asset <core> <arch> <version> <file>
# Rewrites this core/arch line in the lockfile. Only runs with RECORD_HASHES=1.
record_asset() {
  [ "${RECORD_HASHES:-0}" = "1" ] || return 0
  local core="$1" arch="$2" version="$3" file="$4"
  local hash tmp
  hash="$(sha256_of "${file}")"
  tmp="$(mktemp)"
  if [ -f "${LOCK_FILE}" ]; then
    awk -v c="${core}" -v a="${arch}" '!($1 == c && $2 == a)' "${LOCK_FILE}" > "${tmp}"
  fi
  printf '%s %s %s %s\n' "${core}" "${arch}" "${version}" "${hash}" >> "${tmp}"
  # Keep comments first, then the entries sorted, so diffs stay readable.
  { grep '^#' "${tmp}" || true; grep -v '^#' "${tmp}" | grep -v '^[[:space:]]*$' | sort; } \
    > "${LOCK_FILE}"
  rm -f "${tmp}"
  echo "Pinned ${core} ${arch} ${version} ${hash}"
}

# resolve_tag <repo> <core> <arch>
# Uses the pinned version when there is one; falls back to the latest release.
resolve_tag() {
  local repo="$1" core="$2" arch="$3" pinned tag
  pinned="$(lock_version "${core}" "${arch}")"
  if [ -n "${pinned}" ] && [ "${pinned}" != "-" ] && [ "${RECORD_HASHES:-0}" != "1" ]; then
    echo "${pinned}"
    return 0
  fi
  # The releases/latest redirect avoids the unauthenticated API rate limit.
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/${repo}/releases/latest" | sed -E 's#.*/tag/##')"
  [ -n "${tag}" ] || return 1
  echo "${tag}"
}
