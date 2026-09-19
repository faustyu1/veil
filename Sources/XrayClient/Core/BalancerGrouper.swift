import Foundation

/// Groups subscription nodes that are really balancer members of the same
/// logical server (e.g. `NL-01`, `NL-02`, …) into a single `ProxyConfig` with
/// `alternates`. This keeps the server list clean and lets the config builders
/// emit a real Xray/sing-box balancer instead of many separate outbounds.
enum BalancerGrouper {

    /// Applies the heuristic to a fetched body, but only where nothing better
    /// is on offer.
    ///
    /// A config document declares its balancers, and guessing over a
    /// declaration is how a provider's deliberate grouping turns into whatever
    /// their node names happen to look like. Share links declare nothing, so
    /// there the guess is all there is.
    static func applied(to payload: SubscriptionPayload) -> SubscriptionPayload {
        guard !payload.format.isFullConfig else { return payload }
        var grouped = payload
        grouped.servers = group(payload.servers)
        return grouped
    }

    /// Groups servers by normalized name, protocol and auth key. Servers that do
    /// not share a bucket are returned unchanged.
    static func group(_ servers: [ProxyConfig]) -> [ProxyConfig] {
        // Bucket order follows first appearance, not the dictionary's hash
        // order — otherwise the server list reshuffles on every refresh.
        var order: [String] = []
        var buckets: [String: [ProxyConfig]] = [:]
        for server in servers {
            let key = groupKey(for: server)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(server)
        }

        return order.map { key in
            let group = buckets[key]!
            guard group.count > 1 else { return group[0] }
            var main = group[0]
            main.name = baseName(main.name)
            main.alternates = Array(group.dropFirst())
            return main
        }
    }

    private static func groupKey(for server: ProxyConfig) -> String {
        let base = baseName(server.name)
        let auth = NodeIdentity.authKey(for: server) ?? ""
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

}
