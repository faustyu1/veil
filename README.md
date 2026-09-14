# Veil

A native macOS VPN client for the [Xray-core](https://github.com/XTLS/Xray-core) proxy engine, built with SwiftUI. Veil brings a Happ / v2RayTun-style experience to the Mac: subscription profiles, one-click connect, full-traffic tunneling, and professional domain/IP routing — all in a clean menu-bar app.

> **Disclaimer.** Veil is a client for proxy protocols intended for privacy, development, and lawful circumvention of censorship. You are responsible for complying with the laws and terms of service that apply to you. The bundled cores ([Xray-core](https://github.com/XTLS/Xray-core), [tun2socks](https://github.com/xjasonlyu/tun2socks)) are third-party software under their own licenses.

## Features

- **Protocols (two cores)**
  - **Xray-core** — VLESS, VMess, Trojan, Shadowsocks. Reality & TLS security. `tcp`, `ws`, `grpc`, `http`, `xhttp` transports. XTLS `xtls-rprx-vision` flow. VLESS post-quantum encryption (ML-KEM-768 + X25519).
  - **sing-box** — Hysteria2, TUIC, WireGuard, AnyTLS (QUIC-based & modern protocols Xray can't handle). The right core is chosen automatically per server.
- **Two tunnel modes**
  - **System Proxy** — sets the macOS SOCKS/HTTP proxy. No admin password. Covers browsers and proxy-aware apps.
  - **TUN (all apps)** — routes *everything* (Telegram, terminal, games, UDP) through [tun2socks](https://github.com/xjasonlyu/tun2socks). A one-time privileged helper install means server switches never ask for a password again.
- **Privileged helper, not a sudoers rule** — route, DNS and tunnel changes go through a launchd daemon that accepts a fixed set of typed commands from Veil and nothing else. No `NOPASSWD` entry, no root-owned shell scripts, no state in `/tmp`.
- **Secrets in the Keychain** — subscription URLs (whose path *is* the access token) and device identifiers live in the Keychain; the rest of the state is a `0600` file in a `0700` directory. Nothing sensitive reaches the system log, and **Settings → Privacy → Export diagnostics** produces a report with URLs, tokens and IDs already removed.
- **Subscriptions** — import subscription URLs; each becomes its own profile group. Reads `Subscription-Userinfo` (traffic & expiry), `Profile-Title` (name) and `Announce` (description) headers. Auto-update on a configurable interval.
- **QR codes** — show any server as a QR code (copy link or save PNG), and import servers by scanning a QR with the camera or decoding it from an image file.
- **Professional routing** (v2rayN / Nekoray style)
  - Presets: **Global**, **Bypass LAN**, **Bypass China**, **Bypass Russia**, **Custom**.
  - Downloadable `geosite.dat` / `geoip.dat` rule databases from GitHub (Loyalsoldier, runetfreedom, v2fly, or a custom URL).
  - Full ordered rule editor: per-rule outbound (proxy / direct / block), domain & IP matchers (`domain:`, `geosite:`, `keyword:`, `regexp:`, `geoip:cn`, `geoip:private`), port, enable/disable, reordering.
  - One-tap ad & tracker blocking (`geosite:category-ads-all`).
- **Fast switching** — switching servers in the same mode keeps the transport up and only restarts the core, re-pinning the route. Sub-second, no password prompt.
- **Latency testing** — TCP-connect ping per server or per group, with host-route bypass while TUN is active. Sort by ping, filter to alive-only, search.
- **Menu-bar control** — connect / disconnect and quick-switch servers without opening the window.
- **System integration** — launch at login (via `SMAppService`) and macOS notifications on connect / disconnect / reconnect.
- **Quality of life** — collapsible groups, click-to-connect, multi-select deletion (active server is protected), close-to-tray, auto-connect on launch, configurable SOCKS/HTTP ports and core log level, light/dark/system themes.
- **Localized** in 12 languages: English, Русский, 中文, Español, हिन्दी, العربية, Français, Português, Deutsch, 日本語, Bahasa Indonesia, Türkçe.
- **Safe shutdown** — restores routes/DNS on quit and recovers from a crashed previous session so you're never left without internet.

## iOS

This branch also contains the iPhone/iPad app (`ios/`), built on Apple's
**NetworkExtension** so all traffic on the device is tunnelled. It ships
**Xray-core only** — no tun2socks and no second core: Xray's own layer-3 `tun`
inbound takes the utun descriptor straight from `NEPacketTunnelProvider`.

It shares its entire model and core layer with the Mac app (`Sources/XrayClient/`),
so parsers, config builder, subscriptions, routing and localization behave
identically on both platforms.

```bash
Scripts/ios/build-xraycore.sh              # Xray-core -> XrayCore.xcframework
Scripts/ios/build-app.sh simulator Release
```

See **[docs/ios.md](docs/ios.md)** for the packet path, signing requirements and
the app↔extension protocol.

### Why there is no iOS build to download yet

The tunnel needs the `packet-tunnel-provider` Network Extension entitlement.
Apple only issues that entitlement through a **paid Apple Developer Program
membership** ($99/year) — a free personal team cannot provision it.

**Please don't try to sign the app with an ordinary certificate.** It will not
work, and the failure is confusing rather than obvious:

- Sign it with a free personal team and signing fails outright — the
  entitlement is rejected, because entitlements have to be authorised by a
  provisioning profile Apple issued.
- Strip the entitlement to make it build and the app installs and launches
  fine, but the VPN never starts: `NETunnelProviderManager` refuses the
  configuration, and you get an error with no obvious cause.

Re-signing tools that rely on free accounts (AltStore, Sideloadly and friends)
hit the same wall, for the same reason — none of them can grant an entitlement
Apple has not issued.

So the app is buildable from source by anyone who already has a paid account,
but there is no signed build to hand out until the membership is funded.

**Raising the money for the Apple Developer Program membership.** If you'd like
to help:

- **TON** — `UQDsbwQEaspICRDSW4oSNmL0PXxDlnfkiMuqoUbK7ufiCVXj`
- **RUB** — [CloudTips](https://pay.cloudtips.ru/p/a207bf02)

Nothing in the app is paywalled and none of this changes the licence — it is
MIT either way. The membership only buys the ability to ship a build that iOS
will actually run.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel
- Swift 6 toolchain (Xcode 16+) to build from source

## Install (from a release)

1. Download `Veil.app.zip` from the [Releases](../../releases) page.
2. Unzip and move **Veil.app** to `/Applications`.
3. The app is ad-hoc signed. On first launch, right-click → **Open**, or allow it under **System Settings → Privacy & Security**.

## Build from source

```bash
git clone <your-repo-url> veil
cd veil

# Fetch the bundled cores (architecture detected automatically)
Scripts/fetch-xray.sh
Scripts/fetch-singbox.sh
Scripts/fetch-tun2socks.sh

# Optional: regenerate the app icon
Scripts/make-icon.sh

# Build, package into Veil.app, and launch
Scripts/run-app.sh release
```

> A plain `swift run` will not show a window — macOS needs the `.app` bundle that `run-app.sh` assembles (Info.plist, icon, ad-hoc codesign).

### Tests

```bash
swift test
```

Covers the share-link parsers (VLESS/VMess/Trojan/SS/Hysteria2/TUIC/AnyTLS/WireGuard), the link builder (round-trip), both the Xray and sing-box config builders, the subscription format detection and Remnawave header contract, and the redaction and privileged-helper input validation.

The roadmap, and what was corrected in it after reading the code, is in **[docs/PLAN.md](docs/PLAN.md)**.

## Usage

1. **Add servers** — *Subscription* to import a subscription URL, or *Add Link* to paste `vless://` / `vmess://` / `trojan://` / `ss://` / `hysteria2://` / `tuic://` / `anytls://` / `wireguard://` links (one per line). You can also import from a QR code (image file or camera).
2. **Pick a mode** — *Proxy* for browsers, *TUN* for everything. The first TUN connection installs the privileged helper via a single password prompt. Because Veil is ad-hoc signed, the helper pins that exact app binary — reinstall it from *Settings* after updating the app.
3. **Connect** — click a server to select (and connect/switch). The connect button and menu-bar item act on the remembered server.
4. **Routing** — *Settings → Routing → Configure…*. Choose a preset or build custom rules. Geo-based presets download the rule database on first use.

## How it works

```
SwiftUI app (Veil)
 ├─ Xray-core (subprocess)         VLESS/VMess/Trojan/SS — SOCKS + HTTP inbounds on 127.0.0.1
 ├─ sing-box (subprocess)          Hysteria2/TUIC/WireGuard/AnyTLS — same SOCKS + HTTP inbounds
 │    └─ your server outbound + direct/block, routing rules (core chosen per server)
 ├─ System Proxy mode              networksetup points the active service at the SOCKS/HTTP ports
 └─ TUN mode                       tun2socks utun device + split-default routes (0/1 + 128/1),
                                    server IP pinned to the physical gateway
```

- **Privileged helper** — `Scripts/install-daemon.sh` (run once, from the app, with one admin prompt) installs `VeilHelper` and `tun2socks` into `/Library/Application Support/Veil/helper` and loads a LaunchDaemon. The app then talks to it over XPC with typed commands — start/stop the tunnel, pin server addresses, add probe routes — and the helper validates every value it is given. It accepts connections only from the app binary pinned at install time, and refuses every client if that pin is missing.
- **Core binaries** — `Scripts/cores.lock` pins the version and SHA-256 of each downloaded core. The fetch scripts abort on a mismatch; record the hashes once per architecture with `RECORD_HASHES=1 Scripts/fetch-xray.sh` (and the other two).
- **Routing** — `geosite:` matches domains and `geoip:` matches IPs by country, resolved from `geoip.dat` / `geosite.dat` (pointed to via `XRAY_LOCATION_ASSET`).
- **Storage** — settings and the node list persist as a `0600` JSON file in `~/Library/Application Support/XrayClient/`. Subscription URLs and device identifiers are kept in the Keychain instead, and the JSON only records that they are there.

## Project layout

```
Sources/XrayClient/
  App.swift                 app entry, menu-bar extra, lifecycle
  Models/                   ProxyConfig, Subscription, AppSettings, Routing
  Core/                     LinkParser, LinkBuilder, QRCode, SubscriptionFetcher,
                            XrayConfigBuilder, SingBoxConfigBuilder, XrayProcess,
                            SystemProxy, TunManager, PrivilegedHelper, ConnectionManager,
                            ServerStore, Keychain, Redaction, SecureFile, Diagnostics,
                            PingTester, GeoAssetManager, SystemIntegration, Localization
  Views/                    ContentView, MenuBarContent, SettingsSheet, RoutingSheet,
                            AddServerSheet, QRDisplaySheet, CameraScannerView
  Resources/                xray, sing-box, tun2socks (fetched)
Sources/VeilHelperKit/      XPC protocol + input validation shared with the helper
Sources/VeilHelper/         the privileged launchd daemon (routes, DNS, tun2socks)
Scripts/                    fetch-*, cores.lock, run-app.sh, make-icon.sh, *-daemon.sh
Tests/                      parser, link-builder & config-builder tests
```

## Acknowledgements

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — VLESS/VMess/Trojan/SS proxy engine
- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) — Hysteria2/TUIC/WireGuard/AnyTLS engine
- [xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks) — TUN ↔ SOCKS
- Rule databases: [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat), [runetfreedom/russia-v2ray-rules-dat](https://github.com/runetfreedom/russia-v2ray-rules-dat), [v2fly](https://github.com/v2fly)

## License

MIT — see [LICENSE](LICENSE).
