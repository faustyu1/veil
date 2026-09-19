// macOS-only.
#if os(macOS)
import Foundation

/// Turns what the app knows — the server list, the settings, the current
/// selection — into the `SingBoxProfile` the core actually runs.
///
/// Keeping this separate from the connection manager means the profile can be
/// rendered and validated without starting anything, which is what the config
/// preview, the diagnostics export and the tests all want.
enum ProfileAssembler {

    struct Input {
        var servers: [ProxyConfig] = []
        var settings = AppSettings()
        /// The server or group the user picked in the list.
        var activeServerID: UUID?
        var ports = InboundPorts()
        /// True for TUN mode: adds the TUN inbound, which is what makes
        /// process matching work for every application rather than only for
        /// the ones that honour the system proxy.
        var includeTun: Bool = false
        /// Ports of the child Xray processes fronting nodes sing-box cannot
        /// speak. Filled in by `BridgeManager`.
        var bridgePorts: [UUID: Int] = [:]
        var clashSecret: String = ""
        var cacheFilePath: String = ""
    }

    /// Where the core keeps its selector choices and downloaded rule-sets when
    /// it runs as the user. In TUN mode the helper substitutes its own path.
    static var userCachePath: String {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("XrayClient", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])
        return dir.appendingPathComponent("core-cache.db").path
    }

    // MARK: - Assembly

    static func profile(_ input: Input) -> SingBoxProfile {
        let expansion = expand(input.servers, groups: input.settings.serverGroups)

        var profile = SingBoxProfile()
        profile.servers = expansion.servers
        profile.groups = expansion.groups
        profile.defaultTarget = target(for: input.activeServerID,
                                       groups: expansion.groups,
                                       servers: expansion.servers)
        profile.rules = input.settings.effectiveRoutingRules
        profile.explicitRuleSets = input.settings.ruleSets
        profile.dns = input.settings.dns.sanitized()
        profile.ports = input.ports
        profile.logLevel = input.settings.logLevel.rawValue
        profile.bridgePorts = input.bridgePorts
        profile.cacheFilePath = input.cacheFilePath.isEmpty
            ? userCachePath : input.cacheFilePath

        profile.clashAPI.enabled = input.settings.controlAPIEnabled
        profile.clashAPI.port = input.settings.controlAPIPort
        profile.clashAPI.secret = input.clashSecret

        if input.includeTun {
            var tun = TunInboundSettings()
            tun.mtu = input.settings.tunnelMTU > 0 ? input.settings.tunnelMTU : 9000
            tun.strictRoute = input.settings.tunStrictRoute
            tun.stack = input.settings.tunStack
            if !input.settings.ipv6Enabled {
                tun.address = tun.address.filter { !$0.contains(":") }
            }
            profile.tun = tun
        }
        return profile
    }

    /// Servers in this profile that have to be fronted by a child Xray.
    static func bridgedServers(_ input: Input) -> [ProxyConfig] {
        var candidate = profile(input)
        candidate.bridgePorts = [:]
        return SingBoxProfileBuilder.referencedServers(in: candidate)
            .filter { SingBoxOutbound.needsXrayBridge($0) }
    }

    // MARK: - Internals

    /// Which outbound the `proxy` selector should resolve to.
    ///
    /// The picked id may name a group rather than a server — groups and
    /// servers share one selection in the UI, because from the user's side
    /// "connect to this" means the same thing either way.
    static func target(for id: UUID?,
                       groups: [ServerGroup],
                       servers: [ProxyConfig]) -> RuleTarget {
        guard let id else { return .direct }
        if groups.contains(where: { $0.id == id }) { return .group(id) }
        if servers.contains(where: { $0.id == id }) { return .server(id) }
        return .direct
    }

    /// Flattens balancer entries into real nodes plus a group over them.
    ///
    /// A subscription's balancer arrives as one `ProxyConfig` carrying its
    /// alternates. The graph has no place for that shape: every node needs its
    /// own tag, and "pick one of these" is what a group is for.
    static func expand(_ servers: [ProxyConfig],
                       groups: [ServerGroup]) -> (servers: [ProxyConfig], groups: [ServerGroup]) {
        var flattened: [ProxyConfig] = []
        var derived: [ServerGroup] = []

        for server in servers {
            guard server.isBalancer else {
                flattened.append(server)
                continue
            }
            let nodes = [strippedOfAlternates(server)] + (server.alternates ?? [])
            flattened.append(contentsOf: nodes)
            var group = ServerGroup(id: server.id, name: server.name,
                                    kind: .urltest, memberIDs: nodes.map(\.id))
            group.interval = "1m"
            group.tolerance = 150
            derived.append(group)
        }
        // A user-defined group with the same id as a derived one wins: the
        // user configured it on purpose.
        let userIDs = Set(groups.map(\.id))
        return (flattened, groups + derived.filter { !userIDs.contains($0.id) })
    }

    /// The balancer's own node, without the alternates hanging off it — those
    /// are now siblings, and leaving them attached would build the group twice.
    private static func strippedOfAlternates(_ server: ProxyConfig) -> ProxyConfig {
        var copy = server
        copy.alternates = nil
        return copy
    }
}
#endif
