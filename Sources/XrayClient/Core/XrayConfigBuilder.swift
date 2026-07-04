import Foundation

/// Local listening ports for the Xray inbounds. The system proxy points here.
struct InboundPorts {
    var socks: Int = 10808
    var http: Int = 10809
    let listen: String = "127.0.0.1"
}

/// Builds an Xray-core JSON configuration from a `ProxyConfig`.
///
/// Produces two inbounds (SOCKS5 + HTTP) on localhost and one outbound for the
/// selected server, plus a direct outbound for routing rules.
enum XrayConfigBuilder {

    static func build(for cfg: ProxyConfig,
                      ports: InboundPorts = InboundPorts(),
                      rules: [RoutingRule] = [],
                      logLevel: String = "warning") -> [String: Any] {
        let isBalancer = cfg.isBalancer
        let proxyOutbounds = outbounds(for: cfg)
        let balancerTags = isBalancer ? proxyOutbounds.compactMap { $0["tag"] as? String } : []
        return [
            "log": ["loglevel": logLevel],
            "inbounds": inbounds(ports),
            "outbounds": proxyOutbounds + [directOutbound(), blockOutbound()],
            "routing": routing(rules: rules, isBalancer: isBalancer, balancerTags: balancerTags)
        ]
    }

    static func jsonData(for cfg: ProxyConfig,
                         ports: InboundPorts = InboundPorts(),
                         rules: [RoutingRule] = [],
                         logLevel: String = "warning") throws -> Data {
        let dict = build(for: cfg, ports: ports, rules: rules, logLevel: logLevel)
        return try JSONSerialization.data(withJSONObject: dict,
                                          options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Inbounds

    private static func inbounds(_ p: InboundPorts) -> [[String: Any]] {
        [
            [
                "tag": "socks-in",
                "listen": p.listen,
                "port": p.socks,
                "protocol": "socks",
                "settings": ["udp": true, "auth": "noauth"],
                "sniffing": ["enabled": true, "destOverride": ["http", "tls", "quic"]]
            ],
            [
                "tag": "http-in",
                "listen": p.listen,
                "port": p.http,
                "protocol": "http",
                "sniffing": ["enabled": true, "destOverride": ["http", "tls"]]
            ]
        ]
    }

    // MARK: - Outbound dispatch

    private static func singleOutbound(_ cfg: ProxyConfig, tag: String) -> [String: Any] {
        var out: [String: Any]
        switch cfg.proto {
        case .vless:        out = vlessOutbound(cfg)
        case .vmess:        out = vmessOutbound(cfg)
        case .trojan:       out = trojanOutbound(cfg)
        case .shadowsocks:  out = shadowsocksOutbound(cfg)
        case .hysteria2, .tuic, .wireguard, .anytls:
            // Handled by the sing-box core, never here. ConnectionManager routes
            // them to SingBoxConfigBuilder; this is only reachable if called
            // directly, so emit a harmless freedom outbound.
            out = ["protocol": "freedom", "settings": [:]]
        }
        out["tag"] = tag
        if let mux = muxSettings(cfg) { out["mux"] = mux }
        return out
    }

    /// Returns the proxy outbounds for a server. For a normal server this is a
    /// single outbound tagged "proxy"; for a balancer group it emits one
    /// outbound per node (`proxy-0`, `proxy-1`, …) so the routing balancer can
    /// distribute traffic across them.
    private static func outbounds(for cfg: ProxyConfig) -> [[String: Any]] {
        guard cfg.isBalancer else { return [singleOutbound(cfg, tag: "proxy")] }
        let nodes = [cfg] + (cfg.alternates ?? [])
        return nodes.enumerated().map { singleOutbound($1, tag: "proxy-\($0)") }
    }

    /// Connection multiplexing reuses a single TCP/Reality connection for many
    /// streams, cutting handshake overhead. It is INCOMPATIBLE with XTLS
    /// `xtls-rprx-vision` flow, so it is disabled whenever Vision is in use.
    private static func muxSettings(_ cfg: ProxyConfig) -> [String: Any]? {
        if let flow = cfg.flow, flow.contains("vision") { return nil }
        return [
            "enabled": true,
            "concurrency": 8,
            // Keep UDP (DNS, QUIC) on its own connections for lower latency.
            "xudpConcurrency": 16,
            "xudpProxyUDP443": "reject"
        ]
    }

    private static func vlessOutbound(_ cfg: ProxyConfig) -> [String: Any] {
        var user: [String: Any] = [
            "id": cfg.uuid ?? "",
            "encryption": cfg.encryption ?? "none"
        ]
        if let flow = cfg.flow, !flow.isEmpty { user["flow"] = flow }
        return [
            "protocol": "vless",
            "settings": [
                "vnext": [[
                    "address": cfg.address,
                    "port": cfg.port,
                    "users": [user]
                ]]
            ],
            "streamSettings": streamSettings(cfg)
        ]
    }

    private static func vmessOutbound(_ cfg: ProxyConfig) -> [String: Any] {
        let user: [String: Any] = [
            "id": cfg.uuid ?? "",
            "alterId": cfg.alterId ?? 0,
            "security": "auto"
        ]
        return [
            "protocol": "vmess",
            "settings": [
                "vnext": [[
                    "address": cfg.address,
                    "port": cfg.port,
                    "users": [user]
                ]]
            ],
            "streamSettings": streamSettings(cfg)
        ]
    }

    private static func trojanOutbound(_ cfg: ProxyConfig) -> [String: Any] {
        [
            "protocol": "trojan",
            "settings": [
                "servers": [[
                    "address": cfg.address,
                    "port": cfg.port,
                    "password": cfg.password ?? ""
                ]]
            ],
            "streamSettings": streamSettings(cfg)
        ]
    }

    private static func shadowsocksOutbound(_ cfg: ProxyConfig) -> [String: Any] {
        [
            "protocol": "shadowsocks",
            "settings": [
                "servers": [[
                    "address": cfg.address,
                    "port": cfg.port,
                    "method": cfg.method ?? "aes-256-gcm",
                    "password": cfg.password ?? ""
                ]]
            ],
            "streamSettings": streamSettings(cfg)
        ]
    }

    // MARK: - Stream settings (transport + security)

    private static func streamSettings(_ cfg: ProxyConfig) -> [String: Any] {
        var settings: [String: Any] = [
            "network": cfg.network.rawValue,
            "sockopt": [
                // Disable Nagle's algorithm — lower latency for interactive traffic.
                "tcpNoDelay": true,
                // Enable TCP keepalive on the link to the server so idle
                // connections don't get silently dropped from NAT/firewall
                // translation tables (the usual cause of long-idle disconnects).
                "tcpKeepAliveIdle": 30,
                "tcpKeepAliveInterval": 15
            ]
        ]

        // Security layer
        switch cfg.security {
        case .tls:
            settings["security"] = "tls"
            settings["tlsSettings"] = tlsSettings(cfg)
        case .reality:
            settings["security"] = "reality"
            settings["realitySettings"] = realitySettings(cfg)
        case .none:
            settings["security"] = "none"
        }

        // Transport layer
        switch cfg.network {
        case .ws:
            var ws: [String: Any] = ["path": cfg.path ?? "/"]
            if let host = cfg.host, !host.isEmpty {
                ws["headers"] = ["Host": host]
            }
            settings["wsSettings"] = ws
        case .grpc:
            settings["grpcSettings"] = [
                "serviceName": cfg.serviceName ?? cfg.path ?? ""
            ]
        case .http:
            var h: [String: Any] = ["path": cfg.path ?? "/"]
            if let host = cfg.host, !host.isEmpty {
                h["host"] = [host]
            }
            settings["httpSettings"] = h
        case .xhttp:
            var x: [String: Any] = ["path": cfg.path ?? "/"]
            if let host = cfg.host, !host.isEmpty { x["host"] = host }
            if let mode = cfg.xhttpMode, !mode.isEmpty { x["mode"] = mode }
            var extra: [String: Any] = [:]
            if let pad = cfg.xPaddingBytes, !pad.isEmpty {
                extra["xPaddingBytes"] = pad
            }
            if let extraRaw = cfg.xhttpExtra,
               let data = extraRaw.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (k, v) in parsed { extra[k] = v }
            }
            if !extra.isEmpty { x["extra"] = extra }
            settings["xhttpSettings"] = x
        case .tcp, .kcp, .quic:
            break
        }

        return settings
    }

    private static func tlsSettings(_ cfg: ProxyConfig) -> [String: Any] {
        var tls: [String: Any] = [
            "allowInsecure": cfg.allowInsecure
        ]
        if let sni = cfg.sni, !sni.isEmpty { tls["serverName"] = sni }
        if let alpn = cfg.alpn, !alpn.isEmpty { tls["alpn"] = alpn }
        if let fp = cfg.fingerprint, !fp.isEmpty { tls["fingerprint"] = fp }
        return tls
    }

    private static func realitySettings(_ cfg: ProxyConfig) -> [String: Any] {
        var reality: [String: Any] = [:]
        if let sni = cfg.sni { reality["serverName"] = sni }
        if let fp = cfg.fingerprint { reality["fingerprint"] = fp }
        if let pbk = cfg.publicKey { reality["publicKey"] = pbk }
        if let sid = cfg.shortId { reality["shortId"] = sid }
        if let spx = cfg.spiderX { reality["spiderX"] = spx }
        return reality
    }

    // MARK: - Auxiliary outbounds + routing

    private static func directOutbound() -> [String: Any] {
        ["tag": "direct", "protocol": "freedom", "settings": [:]]
    }

    private static func blockOutbound() -> [String: Any] {
        ["tag": "block", "protocol": "blackhole", "settings": [:]]
    }

    /// Builds the routing section from an ordered rule list. The first matching
    /// rule wins. For a balancer group the final catch-all rule uses an Xray
    /// `balancerTag` so traffic is distributed across all nodes.
    private static func routing(rules: [RoutingRule],
                                isBalancer: Bool,
                                balancerTags: [String] = []) -> [String: Any] {
        var ruleList = rules.compactMap { $0.xrayRule(useBalancerForProxy: isBalancer) }
        let finalRule: [String: Any] = [
            "type": "field",
            "network": "tcp,udp",
            isBalancer ? "balancerTag" : "outboundTag": "proxy"
        ]
        ruleList.append(finalRule)

        var routing: [String: Any] = [
            "domainStrategy": "IPIfNonMatch",
            "rules": ruleList
        ]
        if isBalancer && !balancerTags.isEmpty {
            routing["balancers"] = [[
                "tag": "proxy",
                "selector": balancerTags,
                "strategy": ["type": "random"]
            ]]
        }
        return routing
    }
}
