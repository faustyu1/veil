# Milestone 0 security architecture and verification

## Current guarantees

macOS TUN mode uses a typed XPC helper. The helper accepts only loopback SOCKS
coordinates, validated literal endpoint addresses, and resolver addresses. It
never accepts a command, executable, route argument, or filesystem path.

Strict mode loads a dedicated `com.apple/veil` PF anchor that permits loopback,
the tunnel interface, validated VPN endpoint IPs, DHCP, and IPv6 neighbor
discovery, then blocks all other outbound traffic. It also installs IPv4 reject
`/1` routes and then four more-specific `/2`
routes through the tunnel. While the tunnel is healthy the `/2` routes win. If
the core, GUI, helper, or utun interface disappears, the `/1` rejects still win
over a physical default `/0`. Until native IPv6 carriage is available on the
macOS tun2socks path, `::/1` and `8000::/1` are rejected. A literal IPv6 VPN
endpoint is allowed only by a validated host route through the original IPv6
gateway. Strict mode always enables IPv6 protection.

Core configurations live in `~/Library/Caches/dev.local.veil/runtime`, whose
directory is mode `0700`; files are mode `0600`, have opaque names, and are
removed on stop, launch failure, process exit, object destruction, and startup.

Release core discovery accepts only bundled `xray` and `sing-box` executables
whose SHA-256 sidecars match both their bytes and the running architecture.
Debug overrides require both `VEIL_UNSAFE_<CORE>_PATH` and an explicit expected
`VEIL_UNSAFE_<CORE>_SHA256`. There is no automatic sibling, PATH, Homebrew, or
MacPorts fallback.

The helper installer verifies the whole app and nested payload signatures,
accepts only the fixed payload location, rejects symlinks and group/world
writable inputs, verifies a code-signed payload manifest, copies into a
root-only staging directory, checks the staged bytes, replaces the stopped
helper, and verifies installed bytes/signatures again. The app's fixed bootstrap
copies a verified installer script to a root-only temporary file before root
executes it. The installed helper accepts only the narrow Team-ID or exact
development-CDHash requirement written by that installer;
`setCodeSigningRequirement` evaluates it against the XPC peer's audit token.

## Known limitations

- macOS IPv6 is fail-closed (blocked), not tunneled, on the legacy tun2socks path.
- System Proxy mode is not a full tunnel and makes no kill-switch guarantee.
- Ad-hoc development builds have no publisher identity. Only `run-app.sh`
  artifacts explicitly marked as development may install a CDHash-pinned helper.
  Packaged builds require a real Team ID; production release automation must
  provide `VEIL_CODESIGN_IDENTITY` before TUN helper installation is available.
  Notarization and migration to SMAppService remain Milestone 1/P3 work.
- A persisted strict block after a complete app/helper restart can prevent DNS
  needed to reconnect a hostname-only endpoint. Explicit Disconnect removes the
  protection. A future endpoint-address cache or Network Extension migration
  should make this recovery automatic without opening DNS.

## Automated checks

Run on macOS:

```bash
Scripts/fetch-xray.sh
Scripts/fetch-singbox.sh
Scripts/fetch-tun2socks.sh
swift test
bash Tests/SecurityScripts/install-hardening.sh
```

Tests cover malicious IPv4/IPv6/interface values, generated PF policy, address
caps, narrow XPC requirements, route-policy shape, core manifest/hash/architecture rejection, secure config
permissions and stale cleanup, and installer security invariants.

## Manual leak test matrix

Use a disposable macOS test machine. Record the physical interface and public
IPv4/IPv6 before starting. Enable TUN, Strict kill switch, and IPv6 protection.
Keep simultaneous direct IPv4, direct IPv6, and DNS probes running; none may
succeed directly during the fault windows below.

1. Connect and confirm the helper reports `IPv4 + IPv6 fail-closed`.
2. Verify public IPv4 is the VPN address and public IPv6 is unavailable (until
   native IPv6 support replaces blocking).
3. `SIGKILL` xray/sing-box. During reconnect, probes must not use the physical
   IPv4 address and IPv6 must remain unavailable.
4. `SIGKILL` tun2socks. Confirm the `/1` reject routes remain and both probe
   families fail closed.
5. `SIGKILL` Veil and then the helper. Confirm protection remains until an
   explicit disconnect/uninstall recovery action.
6. Make the endpoint unreachable, switch Wi-Fi to hotspot, sleep/wake, and
   disable/re-enable the physical interface. Repeat route and public-address
   checks at every transition.
7. Reconnect, switch servers with A-only, AAAA-only, and A+AAAA endpoints, and
   verify only endpoint host routes bypass protection.
8. Disconnect explicitly. Confirm Veil routes are gone, original DNS is restored,
   and ordinary IPv4/IPv6 connectivity returns.
9. From a separately signed test executable, connect to
   `dev.local.veil.helper` and request `helperVersion`. Confirm XPC rejects the
   peer before any exported method runs; repeat with the right bundle name but
   the wrong Team ID/CDHash.

Do not mark the leak tests passed from UI state alone. Capture `netstat -rn`,
`scutil --dns`, helper logs, and independent public-address probe results.
