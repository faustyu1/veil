# Veil

A native macOS VPN client for the [Xray-core](https://github.com/XTLS/Xray-core) proxy engine, built with SwiftUI. Veil brings a Happ / v2RayTun-style experience to the Mac: subscription profiles, one-click connect, full-traffic tunneling, and professional domain/IP routing — all in a clean menu-bar app.

> **Disclaimer.** Veil is a client for proxy protocols intended for privacy, development, and lawful circumvention of censorship. You are responsible for complying with the laws and terms of service that apply to you. The bundled cores ([Xray-core](https://github.com/XTLS/Xray-core), [tun2socks](https://github.com/xjasonlyu/tun2socks)) are third-party software under their own licenses.

## Features

- **Protocols** — VLESS, VMess, Trojan, Shadowsocks. Reality & TLS security. `tcp`, `ws`, `grpc`, `http` transports. XTLS `xtls-rprx-vision` flow.
- **Two tunnel modes**
  - **System Proxy** — sets the macOS SOCKS/HTTP proxy. No admin password. Covers browsers and proxy-aware apps.
  - **TUN (all apps)** — routes *everything* (Telegram, terminal, games, UDP) through [tun2socks](https://github.com/xjasonlyu/tun2socks). A one-time privileged helper install means server switches never ask for a password again.
- **Subscriptions** — import subscription URLs; each becomes its own profile group. Reads `Subscription-Userinfo` (traffic & expiry), `Profile-Title` (name) and `Announce` (description) headers. Auto-update on a configurable interval.
- **Professional routing** (v2rayN / Nekoray style)
  - Presets: **Global**, **Bypass LAN**, **Bypass China**, **Bypass Russia**, **Custom**.
  - Downloadable `geosite.dat` / `geoip.dat` rule databases from GitHub (Loyalsoldier, runetfreedom, v2fly, or a custom URL).
  - Full ordered rule editor: per-rule outbound (proxy / direct / block), domain & IP matchers (`domain:`, `geosite:`, `keyword:`, `regexp:`, `geoip:cn`, `geoip:private`), port, enable/disable, reordering.
  - One-tap ad & tracker blocking (`geosite:category-ads-all`).
- **Fast switching** — switching servers in the same mode keeps the transport up and only restarts the core, re-pinning the route. Sub-second, no password prompt.
- **Latency testing** — TCP-connect ping per server or per group, with host-route bypass while TUN is active. Sort by ping, filter to alive-only, search.
- **Menu-bar control** — connect / disconnect and quick-switch servers without opening the window.
- **Quality of life** — collapsible groups, click-to-connect, multi-select deletion (active server is protected), close-to-tray, auto-connect on launch, configurable SOCKS/HTTP ports and core log level, light/dark/system themes.
- **Localized** in 12 languages: English, Русский, 中文, Español, हिन्दी, العربية, Français, Português, Deutsch, 日本語, Bahasa Indonesia, Türkçe.
- **Safe shutdown** — restores routes/DNS on quit and recovers from a crashed previous session so you're never left without internet.

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

Covers the share-link parsers (VLESS/VMess/Trojan/SS) and the Xray config builder.

## Usage

1. **Add servers** — *Subscription* to import a subscription URL, or *Add Link* to paste `vless://` / `vmess://` / `trojan://` / `ss://` links (one per line).
2. **Pick a mode** — *Proxy* for browsers, *TUN* for everything. The first TUN connection installs a small root-owned helper via a single password prompt.
3. **Connect** — click a server to select (and connect/switch). The connect button and menu-bar item act on the remembered server.
4. **Routing** — *Settings → Routing → Configure…*. Choose a preset or build custom rules. Geo-based presets download the rule database on first use.

## How it works

```
SwiftUI app (Veil)
 ├─ Xray-core (subprocess)         SOCKS + HTTP inbounds on 127.0.0.1
 │    └─ your server outbound + direct/block, routing rules
 ├─ System Proxy mode              networksetup points the active service at the SOCKS/HTTP ports
 └─ TUN mode                       tun2socks utun device + split-default routes (0/1 + 128/1),
                                    server IP pinned to the physical gateway
```

- **No-password TUN** — a one-time install copies the helper scripts to `/usr/local/libexec/veil`-style location and adds a scoped `NOPASSWD` sudoers rule limited to those exact scripts. Subsequent up/down/switch run via `sudo -n`.
- **Routing** — `geosite:` matches domains and `geoip:` matches IPs by country, resolved from `geoip.dat` / `geosite.dat` (pointed to via `XRAY_LOCATION_ASSET`).
- **Storage** — subscriptions and settings persist as JSON in `~/Library/Application Support/`.

## Project layout

```
Sources/XrayClient/
  App.swift                 app entry, menu-bar extra, lifecycle
  Models/                   ProxyConfig, Subscription, AppSettings, Routing
  Core/                     LinkParser, SubscriptionFetcher, XrayConfigBuilder,
                            XrayProcess, SystemProxy, TunManager, ConnectionManager,
                            ServerStore, PingTester, GeoAssetManager, Localization
  Views/                    ContentView, MenuBarContent, SettingsSheet, RoutingSheet,
                            AddServerSheet
  Resources/                xray, tun2socks (fetched), helper shell scripts
Scripts/                    fetch-*, run-app.sh, make-icon.sh, tun-*, *-helper.sh
Tests/                      parser & config-builder tests
```

## Acknowledgements

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — the proxy engine
- [xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks) — TUN ↔ SOCKS
- Rule databases: [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat), [runetfreedom/russia-v2ray-rules-dat](https://github.com/runetfreedom/russia-v2ray-rules-dat), [v2fly](https://github.com/v2fly)

## License

MIT — see [LICENSE](LICENSE).
