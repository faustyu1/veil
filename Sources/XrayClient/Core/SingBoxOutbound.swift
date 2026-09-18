// macOS-only: sing-box is the routing core on the desktop. The iOS build ships
// Xray-core alone (see ProxyConfig.xraySupported).
#if os(macOS)
import Foundation

/// Turns one `ProxyConfig` into one sing-box outbound (or endpoint).
///
/// This used to live inside `SingBoxConfigBuilder` and cover only the QUIC
/// protocols, because sing-box was the *second* core and Xray handled
/// everything else. Per-process routing changes that: only sing-box can match a
/// process, so it has to be the core that owns the TUN, which means it has to
/// be able to speak every protocol that can be routed. The handful it genuinely
/// cannot speak go through a child Xray process instead — see `needsXrayBridge`.
enum SingBoxOutbound {

    // MARK: - Capability

    /// Transports and features sing-box has no equivalent for, and which
    /// therefore have to be fronted by a local Xray process.
    ///
    /// - XHTTP is an Xray-only transport (upstream sing-box has no `xhttp`).
    /// - mKCP likewise.
    /// - VLESS post-quantum encryption (`mlkem768x25519plus…`) is an Xray
    ///   extension to the VLESS handshake.
    static func needsXrayBridge(_ cfg: ProxyConfig) -> Bool {
        switch cfg.network {
        case .xhttp, .kcp:
            return true
        default:
            break
        }
        if cfg.proto == .vless, let encryption = cfg.encryption {
            let value = encryption.trimmingCharacters(in: .whitespaces).lowercased()
            if !value.isEmpty && value != "none" { return true }
        }
        return false
    }

    /// True when sing-box models this node as a top-level `endpoint` rather
    /// than an outbound (WireGuard, since 1.11).
    static func isEndpoint(_ cfg: ProxyConfig) -> Bool {
        cfg.proto == .wireguard
    }

    // MARK: - Construction

    /// The outbound for `cfg`, tagged `tag`.
    ///
    /// When `bridgePort` is non-nil the node is fronted by a child Xray process
    /// listening on that local SOCKS port, and the outbound is a plain SOCKS
    /// hop into it.
    static func outbound(_ cfg: ProxyConfig, tag: String,
                         bridgePort: Int? = nil,
                         listen: String = "127.0.0.1") -> [String: Any] {
        if let bridgePort {
            return [
                "type": "socks",
                "tag": tag,
                "server": listen,
                "server_port": bridgePort,
                "version": "5"
            ]
        }
        var out: [String: Any]
        switch cfg.proto {
        case .vless:       out = vless(cfg)
        case .vmess:       out = vmess(cfg)
        case .trojan:      out = trojan(cfg)
        case .shadowsocks: out = shadowsocks(cfg)
        case .hysteria2:   out = hysteria2(cfg)
        case .tuic:        out = tuic(cfg)
        case .anytls:      out = anytls(cfg)
        case .wireguard:   out = ["type": "direct"]   // handled as an endpoint
        }
        out["tag"] = tag
        return out
    }

    /// WireGuard as a sing-box `endpoint` (1.11+ schema). The caller places the
    /// result in the top-level `endpoints` array.
    static func endpoint(_ cfg: ProxyConfig, tag: String) -> [String: Any] {
        var peer: [String: Any] = [
            "address": cfg.address,
            "port": cfg.port,
            "public_key": cfg.peerPublicKey ?? "",
            "allowed_ips": ["0.0.0.0/0", "::/0"]
        ]
        if let psk = cfg.presharedKey, !psk.isEmpty { peer["pre_shared_key"] = psk }
        if let reserved = cfg.reserved, reserved.count == 3 { peer["reserved"] = reserved }

        var ep: [String: Any] = [
            "type": "wireguard",
            "tag": tag,
            "address": cfg.localAddresses ?? ["10.0.0.2/32"],
            "private_key": cfg.privateKey ?? "",
            "peers": [peer]
        ]
        if let mtu = cfg.mtu { ep["mtu"] = mtu }
        return ep
    }

    // MARK: - Per-protocol outbounds

    private static func vless(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "vless",
            "server": cfg.address,
            "server_port": cfg.port,
            "uuid": cfg.uuid ?? ""
        ]
        // sing-box only accepts the vision flow; an empty or unknown flow is
        // omitted rather than passed through, which would fail the config check.
        if let flow = cfg.flow, flow == "xtls-rprx-vision" { out["flow"] = flow }
        if let tls = tlsBlock(cfg, defaultALPN: nil) { out["tls"] = tls }
        if let transport = transportBlock(cfg) { out["transport"] = transport }
        return out
    }

    private static func vmess(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "vmess",
            "server": cfg.address,
            "server_port": cfg.port,
            "uuid": cfg.uuid ?? "",
            "security": "auto"
        ]
        if let alterId = cfg.alterId, alterId > 0 { out["alter_id"] = alterId }
        if let tls = tlsBlock(cfg, defaultALPN: nil) { out["tls"] = tls }
        if let transport = transportBlock(cfg) { out["transport"] = transport }
        return out
    }

    private static func trojan(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "trojan",
            "server": cfg.address,
            "server_port": cfg.port,
            "password": cfg.password ?? ""
        ]
        // Trojan is TLS by definition: force the block on even when the link
        // forgot to say `security=tls`.
        out["tls"] = tlsBlock(cfg, defaultALPN: nil, force: true)
        if let transport = transportBlock(cfg) { out["transport"] = transport }
        return out
    }

    private static func shadowsocks(_ cfg: ProxyConfig) -> [String: Any] {
        [
            "type": "shadowsocks",
            "server": cfg.address,
            "server_port": cfg.port,
            "method": cfg.method ?? "aes-256-gcm",
            "password": cfg.password ?? ""
        ]
    }

    private static func hysteria2(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "hysteria2",
            "server": cfg.address,
            "server_port": cfg.port,
            "password": cfg.password ?? ""
        ]
        if let up = cfg.upMbps { out["up_mbps"] = up }
        if let down = cfg.downMbps { out["down_mbps"] = down }
        if let obfs = cfg.obfs, !obfs.isEmpty {
            out["obfs"] = ["type": obfs, "password": cfg.obfsPassword ?? ""]
        }
        out["tls"] = tlsBlock(cfg, defaultALPN: ["h3"], force: true)
        return out
    }

    private static func tuic(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "tuic",
            "server": cfg.address,
            "server_port": cfg.port,
            "uuid": cfg.uuid ?? "",
            "password": cfg.password ?? "",
            "congestion_control": cfg.congestionControl ?? "bbr",
            "udp_relay_mode": cfg.udpRelayMode ?? "native"
        ]
        out["tls"] = tlsBlock(cfg, defaultALPN: ["h3"], force: true)
        return out
    }

    private static func anytls(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "anytls",
            "server": cfg.address,
            "server_port": cfg.port,
            "password": cfg.password ?? ""
        ]
        // AnyTLS speaks regular TLS (not QUIC), so default to HTTP/1.1 ALPN.
        out["tls"] = tlsBlock(cfg, defaultALPN: ["h2", "http/1.1"], force: true)
        return out
    }

    // MARK: - TLS / Reality

    /// The `tls` block, or nil when the node runs in the clear.
    ///
    /// `force` is for protocols that are always encrypted regardless of what
    /// the share link claimed.
    static func tlsBlock(_ cfg: ProxyConfig, defaultALPN: [String]?,
                         force: Bool = false) -> [String: Any]? {
        guard force || cfg.security == .tls || cfg.security == .reality else {
            return nil
        }
        var tls: [String: Any] = ["enabled": true]
        if let sni = cfg.sni, !sni.isEmpty {
            tls["server_name"] = sni
        } else if !cfg.address.isEmpty {
            tls["server_name"] = cfg.address
        }
        tls["insecure"] = cfg.allowInsecure
        if let alpn = cfg.alpn, !alpn.isEmpty {
            tls["alpn"] = alpn
        } else if let defaultALPN {
            tls["alpn"] = defaultALPN
        }
        if cfg.security == .reality {
            var reality: [String: Any] = ["enabled": true]
            if let key = cfg.publicKey, !key.isEmpty { reality["public_key"] = key }
            if let shortId = cfg.shortId, !shortId.isEmpty { reality["short_id"] = shortId }
            tls["reality"] = reality
            // REALITY is a uTLS handshake: sing-box requires the fingerprint.
            let fingerprint = cfg.fingerprint.flatMap { $0.isEmpty ? nil : $0 } ?? "chrome"
            tls["utls"] = ["enabled": true, "fingerprint": normalizedFingerprint(fingerprint)]
        } else if let fp = cfg.fingerprint, !fp.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": normalizedFingerprint(fp)]
        }
        return tls
    }

    /// Xray accepts fingerprint names sing-box does not know (`qq`, `random`,
    /// `randomized`). An unknown value fails the config check, so map the ones
    /// that differ and fall back to `chrome`.
    private static func normalizedFingerprint(_ value: String) -> String {
        let known: Set<String> = [
            "chrome", "firefox", "edge", "safari", "360", "qq", "ios",
            "android", "random", "randomized"
        ]
        let lower = value.lowercased()
        return known.contains(lower) ? lower : "chrome"
    }

    // MARK: - Transport

    /// The `transport` block, or nil for plain TCP.
    static func transportBlock(_ cfg: ProxyConfig) -> [String: Any]? {
        switch cfg.network {
        case .tcp, .xhttp, .kcp:
            // XHTTP and mKCP never reach here: `needsXrayBridge` diverts them.
            return nil
        case .ws:
            var t: [String: Any] = ["type": "ws"]
            if let path = cfg.path, !path.isEmpty { t["path"] = path }
            if let host = cfg.host, !host.isEmpty { t["headers"] = ["Host": host] }
            return t
        case .grpc:
            var t: [String: Any] = ["type": "grpc"]
            if let service = cfg.serviceName, !service.isEmpty {
                t["service_name"] = service
            }
            return t
        case .http:
            var t: [String: Any] = ["type": "http"]
            if let path = cfg.path, !path.isEmpty { t["path"] = path }
            if let host = cfg.host, !host.isEmpty {
                t["host"] = host.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
            }
            return t
        case .quic:
            return ["type": "quic"]
        }
    }
}
#endif
