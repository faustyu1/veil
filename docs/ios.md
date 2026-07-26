# Veil for iOS

The iOS app is a real VPN, not a proxy: it uses Apple's **NetworkExtension**
(`NEPacketTunnelProvider`) so every app on the device is tunnelled — Telegram,
Safari, games, UDP, background traffic.

It ships **one** core: Xray. No tun2socks, no sing-box, no second binary.

## How the packet path works

```
apps ──► iOS routing table ──► utun (created by NetworkExtension)
                                 │  file descriptor
                                 ▼
                       Xray-core `tun` inbound  (gVisor TCP/IP stack)
                                 │  routing rules, sniffing, DNS
                                 ▼
                       VLESS / VMess / Trojan / SS / WireGuard outbound
                                 │
                                 ▼
                              server
```

Xray-core has had a native layer-3 `tun` inbound since v26 (`proxy/tun`), with an
explicit iOS mode: if the `xray.tun.fd` environment flag is set, it adopts that
descriptor instead of opening an interface itself. That is exactly what the
tunnel provider does:

1. `NEPacketTunnelProvider.startTunnel` applies the network settings, which is
   when iOS actually materialises the utun interface.
2. It finds the interface's descriptor — there is no API for this, but the utun
   socket is the only one in the process that answers
   `getsockopt(SYSPROTO_CONTROL, UTUN_OPT_IFNAME)`.
3. `XrayStart(config, fd, …)` publishes the descriptor via `os.Setenv` and boots
   the core.

So the packets never leave the extension process until Xray sends them to the
server. There is no local SOCKS listener and nothing translating TUN to SOCKS.

## Layout

| Path | What it is |
|---|---|
| `ios/Veil.xcodeproj` | App + extension targets |
| `ios/App/` | SwiftUI app (server list, settings, routing, QR) |
| `ios/Tunnel/` | `PacketTunnelProvider` — the whole VPN |
| `ios/Shared/` | App-group paths, app↔extension IPC, config writer |
| `ios/XrayBridge/` | Go package binding Xray-core for gomobile |
| `ios/Config/` | Entitlements + the extension's `Info.plist` |
| `Sources/XrayClient/Models`, `.../Core` | **Shared with macOS**, compiled into both iOS targets |

The parsers, config builder, subscription fetcher, routing model, store, ping
tester and localization are the *same files* the desktop app uses — platform
differences are handled with `#if os(macOS)`, so there is one source of truth
and `swift test` covers both.

## Protocols

Everything Xray-core can do on its own:

| Supported | Not supported on iOS |
|---|---|
| VLESS (Reality, TLS, XTLS Vision, post-quantum encryption) | Hysteria2 |
| VMess | TUIC |
| Trojan | AnyTLS |
| Shadowsocks | |
| WireGuard (Xray's native outbound) | |

Transports: `tcp`, `ws`, `grpc`, `http`, `xhttp`, `kcp`.

The three unsupported ones need the sing-box core, which the iOS build
deliberately does not ship. They still appear in the server list (imported from
subscriptions) but are greyed out and cannot be connected — see
`ProxyConfig.xraySupported`.

## Building

```bash
# 1. Compile Xray-core for iOS (device + simulator). Takes a few minutes.
Scripts/ios/build-xraycore.sh

# 2. Build the app
Scripts/ios/build-app.sh simulator Release
Scripts/ios/build-app.sh device   Release <YOUR_TEAM_ID>
```

`build-xraycore.sh` installs `gomobile` if missing and writes
`ios/Frameworks/XrayCore.xcframework` (gitignored — it is ~110 MB and
reproducible from source). The framework is a **static** library, so it is
linked into the extension and never embedded.

To work in Xcode, open `ios/Veil.xcodeproj` after step 1.

## Signing and capabilities

Running the tunnel on a real device needs a paid Apple Developer account. The
App ID for **both** the app and the extension must have:

- **Network Extensions** → `packet-tunnel-provider`
- **App Groups** → `group.dev.local.veil`

Bundle identifiers are `dev.local.veil` and `dev.local.veil.tunnel`. If you
change them, update `AppGroup.identifier` and
`AppGroup.tunnelBundleIdentifier` in `ios/Shared/AppGroup.swift` and both
`.entitlements` files in `ios/Config/` to match.

The simulator builds without a team, but NetworkExtension does not run there —
the simulator has no VPN stack. Use it for UI work only.

## App ↔ extension

They are separate processes, so everything goes through the shared app group
container `group.dev.local.veil`:

| File | Written by | Read by |
|---|---|---|
| `store.json` | app | app |
| `xray-config.json` | app | extension |
| `session.json` | app | extension |
| `xray.log` | Xray | app (tailed) |
| `last-error.txt` | extension | app |
| `geo/*.dat` | app | Xray |

Live state (traffic counters, log tail, core version) is pulled with
`NETunnelProviderSession.sendProviderMessage` once a second while connected.

**Switching servers does not reconnect the VPN.** The app writes a new config
and sends a `reload` message; the provider restarts only Xray, keeping the same
utun descriptor. iOS never sees the tunnel drop, and the switch is sub-second —
the same trick the desktop app uses with its transport.

## Tunnel shape

- IPv4 `198.18.0.1/24`, default route.
- IPv6 `fd6e:a81b:704f:1211::1/64`, default route — **on by default**. If the
  tunnel only claimed IPv4, IPv6-capable apps would route around it and leak.
  Turn it off in Settings if your server has no IPv6.
- DNS is claimed with `matchDomains = [""]`, so every query enters the tunnel.
  Xray picks port-53 traffic off with a routing rule and answers it from its own
  `dns` section, which resolves through the proxy.
- MTU 1500 by default (adjustable 1280–1500).
- The Go heap is capped at 48 MB with an aggressive GC. NetworkExtension
  processes have a small memory budget and are killed outright when they exceed
  it.

## Reconnect behaviour

The provider watches `NWPathMonitor`. A Wi-Fi ↔ cellular handover invalidates
Xray's sockets but not the utun, so it just restarts the core (debounced 1.5 s)
while `reasserting` is set. `wake()` does the same after the device sleeps.

## Verifying a generated config

The config the app writes is ordinary Xray JSON, so a desktop core can check it:

```bash
XRAY_TUN_FD=1 ./xray run -test -config xray-config.json
```

Without `XRAY_TUN_FD` the desktop core tries to create the interface itself and
fails on permissions — that is expected, and unrelated to the config.
