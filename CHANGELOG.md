# Changelog

All notable changes to Veil are recorded here. Versions follow
[Semantic Versioning](https://semver.org/).

## [1.5.0] — 2026-09-18

### Added

- Rules can name a server or a group, not just "the proxy", so two applications
  can leave the machine through two different servers at once.
- Application rules: pick the app from a searchable list of what is installed
  and what is running. The list shows the executable name, which is what the
  core matches and rarely what is on the icon.
- Server groups — manual, or fastest-wins — that a rule can point at.
- A DNS editor: typed resolvers, per-resolver detours, DNS rules and FakeIP.
- A local control API on 127.0.0.1, off by default, for configuring Veil from
  outside it: rules, groups, resolver, preset, connect. Settings hands over a
  briefing to paste into an assistant.
- Settings for the native TUN inbound: strict route and the network stack.

### Changed

- The separate Subscription and Add Link buttons are now one Add button. It
  accepts a subscription URL, share links, a base64 subscription body, a
  wg-quick profile or a QR code, says what it detected while you type, and
  adds or fetches accordingly.
- sing-box owns the TUN interface, which is what makes application matching
  possible. tun2socks remains as a fallback.
- Your own rules now apply under every preset instead of only "Custom". They
  run after the LAN bypass and before the preset's country rules.
- `geosite:` and `geoip:` entries are no longer dropped from sing-box configs;
  they become rule-sets, which is what sing-box has wanted since 1.12.

The helper protocol is version 5, so **the helper has to be reinstalled** —
Settings → TUN Helper → Install. The app refuses to drive the 1.4.x helper
rather than starting a tunnel it knows is broken.

## [1.4.1] — 2026-09-14

### Fixed

- TUN mode failed to start with `utun123 did not come up`. The bundled
  tun2socks 2.7 parses POSIX-style flags, so the helper's `-device` was read as
  the shorthand `-d` with the value `evice`: tun2socks printed its usage and
  exited without ever creating the interface. The long flags now carry two
  dashes, and the argument list moved into `VeilHelperKit` with a test that
  pins the spelling — a flag this binary cannot parse is silent otherwise.
- The helper no longer waits out the full five seconds when tun2socks has
  already exited, and it reports the last line tun2socks logged instead of only
  saying the interface never appeared.

The helper protocol is version 4, so **the helper has to be reinstalled** —
Settings → TUN Helper → Install. The app refuses to talk to the 1.4.0 helper
rather than driving a tunnel it knows is broken.

## [1.4.0] — 2026-09-14

Phase 0 of `docs/PLAN.md`: the security work that had to land before anything
else was worth shipping. **Everyone upgrading from 1.3.x has to reinstall the
TUN helper once** — Settings → TUN Helper → Install. The old install put a
`NOPASSWD` rule in `/etc/sudoers.d`; the new installer removes it.

### Changed — the privileged helper

- TUN mode no longer runs root shell scripts. `install-helper.sh`, `tun-up.sh`,
  `tun-down.sh` and `tun-ping.sh` are gone, and so is the `NOPASSWD` sudoers
  rule they relied on. In their place is a launchd daemon (`Sources/VeilHelper`)
  that speaks a typed XPC protocol: start and stop the tunnel, pin server
  addresses, add and remove probe routes. No argument names a binary, a path or
  a command, and every address and port is validated again on the root side.
- Tunnel state moved out of `/tmp/xrayclient-*`, where any process could read it
  or pre-create it, into a root-owned `0600` file. The daemon replays that file
  on startup, so a crash can no longer leave the machine without a default
  route.
- The daemon accepts connections only from the app binary pinned at install
  time, and refuses every client when the pinned requirement is missing. Veil
  is ad-hoc signed — there is no paid Apple membership behind it — so the pin is
  a `cdhash` and the helper has to be reinstalled after the app is updated.

### Changed — secrets

- Subscription URLs (whose path is the access token) and device identifiers now
  live in the Keychain. `store.json` keeps only a marker, and is written `0600`
  inside a `0700` directory. If the Keychain is unavailable the URL stays in the
  file rather than being lost.
- The subscription fetch no longer logs the URL, the HWID or the token.
- Settings gained an **Export diagnostics** button that redacts credentials
  before it copies, so a report can be pasted into an issue unread.

### Changed — device identifier

- The HWID was the machine's `IOPlatformUUID`: stable across reinstalls and
  identical for every provider. New installs now mint a random identifier, one
  per subscription, rotatable from Settings.
- Installs that already talked to a panel carry their current identifier
  forward. Rotating silently would look like a new device and could trip
  `x-hwid-max-devices-reached` — that is, disconnect someone mid-use.

### Changed — Remnawave

- The whole response-header contract is parsed instead of three headers:
  `x-hwid-active`, `x-hwid-not-supported`, `x-hwid-max-devices-reached`,
  `subscription-userinfo`, `profile-title`, `profile-update-interval`,
  `announce`, `support-url`, `profile-web-page-url` and
  `subscription-refill-date`.
- The HWID goes in `X-Hwid` and nowhere else. It used to travel in two query
  parameters, two headers and the User-Agent — the last of which showed it to
  every proxy on the path. The User-Agent is now overridable per subscription.
- The response body is classified — `XRAY_JSON`, `XRAY_BASE64`, `SINGBOX`,
  Mihomo YAML, plain share links — and kept verbatim instead of being flattened
  into a node list.

### Changed — supply chain

- `Scripts/cores.lock` pins each bundled core's version and SHA-256, and the
  fetch scripts abort on a mismatch: Xray-core 26.3.27, sing-box 1.14.0,
  tun2socks 2.7.0 (arm64).
- Geo databases are staged, checked for size and content, and swapped in as a
  pair, with the previous pair kept for rollback. Routing with one new and one
  old database is worse than not updating at all.

### Fixed

- A fresh install adopted the machine's `IOPlatformUUID` as its HWID, because
  the legacy-identifier reader on macOS always succeeds. It is now consulted
  only when an earlier install actually left a store behind.
- Installing the helper from Settings ran the admin prompt and an XPC round trip
  on the main thread and discarded the error, so a cancelled password prompt
  looked like a button that does nothing. Both run off the main thread now, the
  row shows progress, and failures are shown.

[1.4.1]: https://github.com/faustyu1/veil/releases/tag/v1.4.1
[1.4.0]: https://github.com/faustyu1/veil/releases/tag/v1.4.0
