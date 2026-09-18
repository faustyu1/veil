// macOS-only: sing-box is the routing core on the desktop. The iOS build ships
// Xray-core alone, so protocols that need sing-box are unavailable there
// (see ProxyConfig.xraySupported).
#if os(macOS)
import Foundation

/// Single-server sing-box configuration.
///
/// This is the narrow entry point the connection manager uses when it only has
/// one node to run — the old "second core for QUIC protocols" case. It is a
/// thin wrapper over `SingBoxProfileBuilder`, which does the real work and can
/// also express a whole graph of servers, groups and per-process rules.
enum SingBoxConfigBuilder {

    static func build(for cfg: ProxyConfig,
                      ports: InboundPorts = InboundPorts(),
                      rules: [RoutingRule] = [],
                      logLevel: String = "warning") -> [String: Any] {
        SingBoxProfileBuilder.build(profile(for: cfg, ports: ports,
                                            rules: rules, logLevel: logLevel))
    }

    static func jsonData(for cfg: ProxyConfig,
                         ports: InboundPorts = InboundPorts(),
                         rules: [RoutingRule] = [],
                         logLevel: String = "warning") throws -> Data {
        try SingBoxProfileBuilder.jsonData(profile(for: cfg, ports: ports,
                                                   rules: rules, logLevel: logLevel))
    }

    /// Wraps one server (plus its balancer alternates, if any) in a profile.
    static func profile(for cfg: ProxyConfig,
                        ports: InboundPorts,
                        rules: [RoutingRule],
                        logLevel: String) -> SingBoxProfile {
        var profile = SingBoxProfile()
        profile.ports = ports
        profile.rules = rules
        profile.logLevel = logLevel
        // No control API and no cache file for the throwaway single-server
        // config: it would fight the port the full profile listens on.
        profile.clashAPI.enabled = false
        // The resolver belongs to the full profile; here the system one is
        // already in place and the config only has to reach one server.
        profile.dns.enabled = false

        if cfg.isBalancer {
            let nodes = [cfg] + (cfg.alternates ?? [])
            profile.servers = nodes
            var group = ServerGroup(id: cfg.id, name: cfg.name, kind: .urltest,
                                    memberIDs: nodes.map(\.id))
            group.testURL = "http://www.gstatic.com/generate_204"
            group.interval = "1m"
            group.tolerance = 150
            profile.groups = [group]
            profile.defaultTarget = .group(cfg.id)
        } else {
            profile.servers = [cfg]
            profile.defaultTarget = .server(cfg.id)
        }
        return profile
    }
}
#endif
