import Foundation

/// Groups subscription nodes that are really balancer members of the same
/// logical server (e.g. `NL-01`, `NL-02`, …) into a single `ProxyConfig` with
/// `alternates`. This keeps the server list clean and lets the config builders
/// emit a real Xray/sing-box balancer instead of many separate outbounds.
enum BalancerGrouper {

    /// Groups servers by normalized name, protocol and auth key. Servers that do
    /// not share a bucket are returned unchanged.
    static func group(_ servers: [ProxyConfig]) -> [ProxyConfig] {
        var buckets: [String: [ProxyConfig]] = [:]
        for server in servers {
            let key = groupKey(for: server)
            buckets[key, default: []].append(server)
        }

        var result: [ProxyConfig] = []
        for group in buckets.values {
            guard group.count > 1 else {
                result.append(group[0])
                continue
            }
            var main = group[0]
            main.name = baseName(main.name)
            main.alternates = Array(group.dropFirst())
            result.append(main)
        }
        return result
    }

    private static func groupKey(for server: ProxyConfig) -> String {
        let base = baseName(server.name)
        let auth = authKey(for: server) ?? ""
        return "\(base)|\(server.proto.rawValue)|\(auth)"
    }

    /// Strips a trailing numeric suffix such as `-01`, ` - 1`, `| 2 - 1` so that
    /// `NL-01` and `NL-07` share the base name `NL`, and `NL-TN-01` shares
    /// `NL-TN` with `NL-TN-02`.
    private static func baseName(_ name: String) -> String {
        let pattern = #"[—–\-|]\s*\d+\s*$"#
        return name
            .replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Returns a stable auth key for grouping balancer members. VLESS/VMess use
    /// the UUID, Trojan/SS/Hysteria2/TUIC/AnyTLS use the password, WireGuard
    /// uses the peer public key.
    private static func authKey(for server: ProxyConfig) -> String? {
        switch server.proto {
        case .vless, .vmess:
            return server.uuid
        case .trojan, .shadowsocks, .hysteria2, .tuic, .anytls:
            return server.password
        case .wireguard:
            return server.peerPublicKey
        }
    }
}
