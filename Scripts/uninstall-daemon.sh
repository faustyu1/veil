#!/bin/bash
# uninstall-daemon.sh — removes the Veil privileged helper and every trace of
# the older sudoers-based install. Run as root (one admin prompt).
set -uo pipefail

LABEL="dev.local.veil.helper"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
INSTALL_DIR="/Library/Application Support/Veil/helper"

log() { echo "[uninstall-daemon] $*"; }

if [ "$(id -u)" != "0" ]; then
  log "ERROR: must run as root"; exit 1
fi

# Ask the helper's own teardown to run before the daemon goes away: booting it
# out with a tunnel up would leave the machine without a default route.
STATE="${INSTALL_DIR}/tunnel-state.json"
PF_TOKEN="$(/usr/bin/plutil -extract pfEnableToken raw "${STATE}" 2>/dev/null || true)"
if [ -x "${INSTALL_DIR}/VeilHelper" ]; then
  "${INSTALL_DIR}/VeilHelper" --cleanup >/dev/null 2>&1 || true
fi
if /bin/launchctl print "system/${LABEL}" >/dev/null 2>&1; then
  /bin/launchctl bootout "system/${LABEL}" 2>/dev/null || true
  log "unloaded ${LABEL}"
fi

# Whatever state was left behind, put the routes back by hand.
/sbin/route -n delete -net 0.0.0.0/1 >/dev/null 2>&1 || true
/sbin/route -n delete -net 128.0.0.0/1 >/dev/null 2>&1 || true
for net in 0.0.0.0/2 64.0.0.0/2 128.0.0.0/2 192.0.0.0/2; do
  /sbin/route -n delete -net "${net}" >/dev/null 2>&1 || true
done
/sbin/route -n delete -inet6 -net ::/1 >/dev/null 2>&1 || true
/sbin/route -n delete -inet6 -net 8000::/1 >/dev/null 2>&1 || true
/sbin/pfctl -a com.apple/veil -F rules >/dev/null 2>&1 || true
case "${PF_TOKEN}" in
  ''|*[!0-9]*) ;;
  *) /sbin/pfctl -X "${PF_TOKEN}" >/dev/null 2>&1 || true ;;
esac

/bin/rm -f "${PLIST}"
/bin/rm -rf "${INSTALL_DIR}"
/bin/rmdir "/Library/Application Support/Veil" 2>/dev/null || true

# Legacy install.
/bin/rm -f /etc/sudoers.d/xrayclient
/bin/rm -rf /usr/local/libexec/xrayclient
/bin/rm -f /tmp/xrayclient-tun2socks.pid /tmp/xrayclient-tun.state \
           /tmp/xrayclient-tun.pinned /tmp/xrayclient-ping.pinned /tmp/tun2socks.log

log "Helper removed."
