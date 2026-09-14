#!/bin/bash
# Installs Veil's fixed privileged helper payload. The app bundle signature is
# the trust root; payload.sha256 pins the exact files copied after verification.
set -euo pipefail

PAYLOAD_DIR="${1:-}"
APP_BUNDLE="${2:-}"
LABEL="dev.local.veil.helper"
BASE_DIR="/Library/Application Support/Veil"
INSTALL_DIR="${BASE_DIR}/helper"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
MANIFEST="${PAYLOAD_DIR}/payload.sha256"

log() { echo "[install-daemon] $*"; }
fail() { log "ERROR: $*"; exit 1; }
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

[ "$(/usr/bin/id -u)" = "0" ] || fail "must run as root"
[ -n "${PAYLOAD_DIR}" ] && [ -d "${PAYLOAD_DIR}" ] || fail "payload directory missing"
[ -n "${APP_BUNDLE}" ] && [ -d "${APP_BUNDLE}" ] || fail "app bundle missing"

# Canonicalize without following a caller-selected destination. The only
# accepted payload is the fixed directory inside the app being authenticated.
APP_BUNDLE="$(cd "${APP_BUNDLE}" && /bin/pwd -P)"
PAYLOAD_DIR="$(cd "${PAYLOAD_DIR}" && /bin/pwd -P)"
[ "${PAYLOAD_DIR}" = "${APP_BUNDLE}/Contents/Library/VeilHelper" ] \
  || fail "payload is not inside the authenticated app bundle"

/usr/bin/codesign --verify --deep --strict "${APP_BUNDLE}" \
  || fail "app signature verification failed"

for file in VeilHelper tun2socks install-daemon.sh uninstall-daemon.sh payload.sha256; do
  path="${PAYLOAD_DIR}/${file}"
  [ -f "${path}" ] || fail "missing ${file}"
  [ ! -L "${path}" ] || fail "${file} must not be a symlink"
  mode="$(/usr/bin/stat -f '%Lp' "${path}")"
  [ $((8#${mode} & 8#022)) -eq 0 ] || fail "${file} is group/world writable"
done

/usr/bin/codesign --verify --strict "${PAYLOAD_DIR}/VeilHelper" \
  || fail "helper signature verification failed"
/usr/bin/codesign --verify --strict "${PAYLOAD_DIR}/tun2socks" \
  || fail "tun2socks signature verification failed"

verify_manifest_file() {
  local name="$1" expected actual matches
  matches="$(/usr/bin/awk -v n="${name}" '$2 == n || $2 == "*" n { print $1 }' "${MANIFEST}")"
  [ "$(printf '%s\n' "${matches}" | /usr/bin/awk 'NF { n++ } END { print n+0 }')" -eq 1 ] \
    || fail "manifest must contain exactly one ${name} entry"
  expected="${matches}"
  case "${expected}" in
    *[!0-9a-fA-F]*|'') fail "invalid hash for ${name}" ;;
  esac
  [ "${#expected}" -eq 64 ] || fail "invalid hash length for ${name}"
  actual="$(sha256 "${PAYLOAD_DIR}/${name}")"
  [ "${actual}" = "${expected}" ] || fail "source hash mismatch for ${name}"
}

verify_manifest_file VeilHelper
verify_manifest_file tun2socks
verify_manifest_file install-daemon.sh
verify_manifest_file uninstall-daemon.sh

SIGN_INFO="$(/usr/bin/codesign -d --verbose=4 "${APP_BUNDLE}" 2>&1)"
IDENTIFIER="$(printf '%s\n' "${SIGN_INFO}" | /usr/bin/awk -F= '/^Identifier=/{print $2; exit}')"
TEAM_ID="$(printf '%s\n' "${SIGN_INFO}" | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}')"
CDHASH="$(printf '%s\n' "${SIGN_INFO}" | /usr/bin/awk -F= '/^CDHash=/{print $2; exit}')"
[ "${IDENTIFIER}" = "dev.local.veil" ] || fail "unexpected app identifier"
DEV_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :VeilDevelopmentBuild' \
  "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || true)"

if [ -n "${TEAM_ID}" ] && [ "${TEAM_ID}" != "not set" ]; then
  REQUIREMENT="anchor apple generic and identifier \"${IDENTIFIER}\" and certificate leaf[subject.OU] = \"${TEAM_ID}\""
  log "pinning client by team ${TEAM_ID}"
elif [ -n "${CDHASH}" ] && [ "${DEV_BUILD}" = "true" ]; then
  REQUIREMENT="identifier \"${IDENTIFIER}\" and cdhash H\"${CDHASH}\""
  log "pinning development client by cdhash"
else
  fail "production helper installation requires a Team-ID-signed app"
fi

# Copy into a root-only staging directory. Source and staged hashes must both
# match the signed manifest, closing the verification/copy race.
/bin/mkdir -p "${BASE_DIR}"
/usr/sbin/chown root:wheel "${BASE_DIR}"
/bin/chmod 0755 "${BASE_DIR}"
STAGE="$(/usr/bin/mktemp -d "${BASE_DIR}/.helper.install.XXXXXX")"
OLD_DIR="${BASE_DIR}/.helper.previous"
ACTIVATED=0
/bin/rm -rf "${OLD_DIR}"
cleanup() {
  /bin/rm -rf "${STAGE}"
  if [ "${ACTIVATED}" -eq 0 ] && [ -d "${OLD_DIR}" ]; then
    /bin/rm -rf "${INSTALL_DIR}"
    /bin/mv "${OLD_DIR}" "${INSTALL_DIR}"
    /bin/launchctl bootstrap system "${PLIST}" 2>/dev/null || true
  fi
}
trap cleanup EXIT
/usr/sbin/chown root:wheel "${STAGE}"
/bin/chmod 0700 "${STAGE}"

for file in VeilHelper tun2socks; do
  /usr/bin/install -m 0755 -o root -g wheel "${PAYLOAD_DIR}/${file}" "${STAGE}/${file}"
  expected="$(/usr/bin/awk -v n="${file}" '$2 == n || $2 == "*" n { print $1; exit }' "${MANIFEST}")"
  [ "$(sha256 "${STAGE}/${file}")" = "${expected}" ] || fail "staged hash mismatch for ${file}"
done

printf '%s\n' "${REQUIREMENT}" > "${STAGE}/client.requirement"
/usr/sbin/chown root:wheel "${STAGE}/client.requirement"
/bin/chmod 0644 "${STAGE}/client.requirement"
/usr/bin/codesign --verify --strict "${STAGE}/VeilHelper"
/usr/bin/codesign --verify --strict "${STAGE}/tun2socks"

/bin/launchctl bootout "system/${LABEL}" 2>/dev/null || true
if [ -d "${INSTALL_DIR}" ]; then /bin/mv "${INSTALL_DIR}" "${OLD_DIR}"; fi
/bin/mv "${STAGE}" "${INSTALL_DIR}"
STAGE="${BASE_DIR}/.helper.install.complete"
/bin/chmod 0755 "${INSTALL_DIR}"

for file in VeilHelper tun2socks; do
  expected="$(/usr/bin/awk -v n="${file}" '$2 == n || $2 == "*" n { print $1; exit }' "${MANIFEST}")"
  [ "$(sha256 "${INSTALL_DIR}/${file}")" = "${expected}" ] || fail "installed hash mismatch for ${file}"
done
/usr/bin/codesign --verify --strict "${INSTALL_DIR}/VeilHelper"
/usr/bin/codesign --verify --strict "${INSTALL_DIR}/tun2socks"

PLIST_TMP="${PLIST}.new"
/bin/cat > "${PLIST_TMP}" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key><array><string>${INSTALL_DIR}/VeilHelper</string></array>
  <key>MachServices</key><dict><key>${LABEL}</key><true/></dict>
  <key>RunAtLoad</key><false/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Background</string>
</dict></plist>
PLISTEOF
/usr/sbin/chown root:wheel "${PLIST_TMP}"
/bin/chmod 0644 "${PLIST_TMP}"
/bin/mv -f "${PLIST_TMP}" "${PLIST}"
/bin/launchctl bootstrap system "${PLIST}"
ACTIVATED=1
/bin/rm -rf "${OLD_DIR}"

# Remove legacy privileged paths only after the verified helper is live.
/bin/rm -f /etc/sudoers.d/xrayclient
/bin/rm -rf /usr/local/libexec/xrayclient
/bin/rm -f /tmp/xrayclient-tun2socks.pid /tmp/xrayclient-tun.state \
           /tmp/xrayclient-tun.pinned /tmp/xrayclient-ping.pinned /tmp/tun2socks.log
log "verified helper installed to ${INSTALL_DIR}"
