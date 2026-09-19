# Changelog

All notable changes to Veil are recorded here. Versions follow
[Semantic Versioning](https://semver.org/).

## [1.7.0] — 2026-09-19

### Added

- Balancer groups a panel declares are now used as declared. A subscription
  that answers with a sing-box or Xray config states its grouping outright —
  a `urltest` or `selector` outbound, a `routing.balancers` entry — and Veil
  reads that instead of re-deriving one from the node names. Each group shows
  up in the list as a single entry you can connect to, with its members
  underneath.
- An Intel build, `Veil-x86_64.app.zip`. Releases used to ship only the Apple
  Silicon archive, which Intel Macs refuse to open with "this application is
  not supported on this Mac". The updater now fetches the archive matching the
  Mac it runs on.
- `CONTRIBUTING.md`, a Contributor Covenant `CODE_OF_CONDUCT.md`, and a
  `CLAUDE.md` recording the rules that are easy to get wrong — the helper's
  cdhash pin, the TUN stack, the localization table, the build SDK.

### Changed

- The name heuristic that merges `NL - 1` and `NL - 2` into one balancer now
  runs only for subscriptions that are a list of share links. Those carry no
  grouping at all, so a guess is all there is; a config document does carry
  one, and guessing over it replaced the provider's intent with whatever their
  node names happened to look like.
- Veil is now licensed under the **GNU Affero General Public License v3.0**
  instead of MIT. The bundled cores keep their own licences and nothing in the
  app is paywalled; the change only requires that anyone who distributes a
  modified Veil, or runs one over a network, offers the source for it.
- The README is rewritten around what Veil actually does, with the protocol
  matrix, the two tunnel modes and the security model up front, and a Russian
  translation in `README.ru.md`.

### Removed

- `docs/PLAN.md`. The roadmap had outlived the work it described; the
  CHANGELOG and the issue tracker say what is done and what is next.

## [1.6.3] — 2026-09-19

### Fixed

- The Device ID on screen did not change when it was regenerated. The row read
  the identifier from a static store SwiftUI does not observe, so the new value
  only appeared once something unrelated redrew the row — pressing Copy, for
  instance, which is how it looked like copying was what rotated it.
- Veil no longer goes quiet after it updates itself. The helper pins its client
  by code hash and every build has a different one, so an installed update left
  a helper that refuses the app and a TUN mode that cannot start. The main
  window now says so and offers the reinstall, instead of leaving it to be
  found in Settings.

### Added

- The Device ID can be set by hand, for providers that issue one of their own.
  It is stored exactly as typed rather than folded into Veil's own format.

### Changed

- The subscription check interval is a list of useful intervals — hourly up to
  weekly — rather than a stepper that moved one hour at a time between 1 and
  168. An interval an earlier build stored stays selectable. The row is hidden
  altogether while auto-update is off, since it governs nothing then.

## [1.6.2] — 2026-09-19

### Fixed

- TUN mode carried no TCP traffic at all on a default install. The tunnel's
  network stack was left for the core to choose, and sing-box 1.14 — the
  version pinned in `Scripts/cores.lock` — chooses `mixed`, a gVisor UDP stack
  over a system TCP stack whose macOS half never answers a SYN. Pings were
  replied to, DNS resolved through the tunnel and the core logged nothing, so
  everything read as connected while every connection hung until it timed out.
  The tunnel now asks for `gvisor`, which handles both halves. Picking a stack
  by hand in Settings still overrides it.

## [1.6.1] — 2026-09-19

### Fixed

- Nodes that need the Xray bridge — XHTTP, mKCP, VLESS with post-quantum
  encryption — connected and then carried nothing, in both System Proxy and TUN
  mode. The bridge was built with Xray's `mux.cool` multiplexing switched on,
  which the servers these subscriptions come from do not accept: the handshake
  succeeded, the request went out addressed to `v1.mux.cool`, and every stream
  died with `failed to read metadata`. At the default log level none of that was
  printed, so the tunnel looked healthy while moving zero bytes. No outbound
  enables mux any more, which is also Xray's own default.
- The DNS catch-all can no longer be the bootstrap resolver. That entry is
  pinned to `direct` so a node's hostname can be resolved before the tunnel
  exists; selecting it as "Answer with" sent every lookup out in the clear, to
  the resolver the tunnel was turned on to get away from. It is now left out of
  the picker and corrected on the way to the core.
- TUN mode could report "tunnel up" over a tunnel that was already dead. The
  helper treated the appearance of a `utun` device as success, but sing-box
  creates the interface before it installs the routes that make it useful, so a
  core that failed on `auto_route` was still alive at that instant. The device
  now starts a grace period instead of ending the check.

### Changed

- The routing core's log now reaches the app's log window in TUN mode. It runs
  as root there and writes to a file the app cannot open, so the window used to
  show only the Xray bridge — a core that came up and then misbehaved left no
  trace at all. Terminal colour codes are stripped on the way in, in both modes.

## [1.6.0] — 2026-09-18

### Added

- In-app updates. Veil checks its GitHub releases, shows what changed, downloads
  the new build with a real byte counter and a Cancel button, and swaps the
  bundle on the next launch. A check the user asks for answers with a standard
  system alert when there is nothing to install, with a Version History button
  next to OK.
- An About window with the version, the build and the links people actually
  follow.
- Community rule lists: curated domain and IP lists that can be switched on in
  Routing and pointed at proxy, direct or block. The lists are cached on disk
  and refreshed on demand; only the chosen ids are stored in settings.
- Settings and Routing are windows of their own — ⌘, opens Settings — with the
  section switcher in the title bar instead of a tab strip below it.

### Changed

- The interface was rebuilt on native macOS components throughout: the groups
  editor no longer shows a checklist of every server that exists, the
  application picker has search, scopes and real checkboxes, and the DNS editor
  lays its fields out as labelled rows instead of stretched text fields.
- Release builds are stamped with the SDK they were built against, so the app
  renders in the current macOS style rather than the legacy one.
- All secrets now live in a single keychain item. Veil is signed ad hoc, so its
  code hash changes with every build and macOS asks for authorisation again —
  one item means one dialog instead of one per subscription per launch.
- The device identifier is 16 hexadecimal characters instead of a full UUID.
  Existing installs keep a stable prefix of the identifier they already had.
- The User-Agent carries only the client name and version. The device facts stay
  in the `X-Device-*` headers, which only the panel reads.
- Connecting and switching servers is faster: the SOCKS port is polled every
  25 ms instead of waiting out a fixed delay, the system proxy is configured off
  the main actor, and the primary network service is cached for 15 seconds and
  re-resolved when the network changes.
- Plans with no traffic cap are shown as unlimited instead of "Zero KB".

### Fixed

- The Xray access log no longer goes to standard output. A busy connection could
  produce thousands of lines a second, which flooded the log view and could take
  the app down with it; core output is now buffered and capped as well.
- Stopping a core waits for the process to exit, so the replacement can bind the
  SOCKS port instead of failing and being retried by the watchdog.
- The empty state in Groups is centred in the window.
- `Scripts/run-app.sh` quits the running copy before relaunching, instead of
  activating the old process and appearing to do nothing.

## [1.5.1] — 2026-09-18

### Fixed

- The tunnel no longer fails to start with "detour to an empty direct outbound
  makes no sense" when the DNS bootstrap resolver is set to `direct`. The
  `direct` detour is now omitted, matching sing-box 1.12+ semantics.

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
