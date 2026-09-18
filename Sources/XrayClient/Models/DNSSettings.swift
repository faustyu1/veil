import Foundation

/// One DNS server in the sing-box resolver.
///
/// sing-box 1.12 replaced the old `"address": "tls://1.1.1.1"` string with a
/// typed object, so this models the typed form directly: a `type`, a bare
/// `server` host, and transport-specific extras.
struct DNSServerEntry: Codable, Equatable, Identifiable, Hashable {

    enum Kind: String, Codable, CaseIterable, Identifiable, Hashable {
        case local      // whatever the system resolver is
        case udp
        case tcp
        case tls        // DoT
        case https      // DoH
        case quic       // DoQ
        case h3         // DoH3
        case fakeip

        var id: String { rawValue }

        var title: String {
            switch self {
            case .local:  return "System"
            case .udp:    return "UDP"
            case .tcp:    return "TCP"
            case .tls:    return "DNS over TLS"
            case .https:  return "DNS over HTTPS"
            case .quic:   return "DNS over QUIC"
            case .h3:     return "DNS over HTTP/3"
            case .fakeip: return "FakeIP"
            }
        }

        /// Types that need a host to talk to.
        var needsServer: Bool {
            switch self {
            case .local, .fakeip: return false
            default:              return true
            }
        }

        /// Types that carry an HTTP path.
        var needsPath: Bool { self == .https || self == .h3 }
    }

    var id = UUID()
    var tag: String
    var kind: Kind = .udp
    /// Hostname or IP. Ignored for `.local` and `.fakeip`.
    var server: String = ""
    var port: Int?
    /// DoH/DoH3 query path. Empty means the default `/dns-query`.
    var path: String = ""
    /// Outbound tag this server's own queries go through. Empty = default
    /// route. A resolver reached through the proxy hides your lookups; one on
    /// `direct` is faster and is what the bootstrap resolver must use.
    ///
    /// sing-box 1.12+ refuses `detour: "direct"` against an empty `direct`
    /// outbound ("detour to an empty direct outbound makes no sense"), and an
    /// unset detour already resolves through an empty direct dialer, so a
    /// `direct` detour is dropped at render time (see `json(_:_:)`).
    var detour: String = ""
    /// Per-server address family preference. Empty = inherit.
    var strategy: String = ""

    init(id: UUID = UUID(), tag: String, kind: Kind = .udp,
         server: String = "", port: Int? = nil, path: String = "",
         detour: String = "", strategy: String = "") {
        self.id = id
        self.tag = tag
        self.kind = kind
        self.server = server
        self.port = port
        self.path = path
        self.detour = detour
        self.strategy = strategy
    }

    /// sing-box `dns.servers[]` entry, or nil when it is not usable.
    func json(fakeIPv4: String, fakeIPv6: String) -> [String: Any]? {
        var dict: [String: Any] = ["type": kind.rawValue, "tag": tag]
        switch kind {
        case .local:
            break
        case .fakeip:
            dict["inet4_range"] = fakeIPv4
            dict["inet6_range"] = fakeIPv6
        default:
            let host = server.trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty else { return nil }
            dict["server"] = host
            if let port { dict["server_port"] = port }
            if kind.needsPath, !path.isEmpty { dict["path"] = path }
        }
        // An empty direct outbound is sing-box's default dialer, so naming it
        // as a detour is redundant and, since 1.12, fatal. Drop it and let the
        // server fall back to the (equivalent) empty direct dialer.
        if !detour.isEmpty && kind != .fakeip && kind != .local
            && detour != ProfileTags.direct {
            dict["detour"] = detour
        }
        if !strategy.isEmpty { dict["strategy"] = strategy }
        return dict
    }

    private enum CodingKeys: String, CodingKey {
        case id, tag, kind, server, port, path, detour, strategy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        id = get(.id, UUID())
        tag = get(.tag, "dns")
        kind = get(.kind, .udp)
        server = get(.server, "")
        port = try? c.decode(Int.self, forKey: .port)
        path = get(.path, "")
        detour = get(.detour, "")
        strategy = get(.strategy, "")
    }
}

/// "Resolve these names with that server." Same matcher vocabulary as a routing
/// rule, minus the parts DNS cannot see (there is no destination IP yet when a
/// name is being resolved).
struct DNSRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var enabled: Bool = true
    /// Tag of the `DNSServerEntry` that answers matching queries.
    var serverTag: String = ""
    var domains: [String] = []
    var processNames: [String] = []
    var ruleSets: [String] = []
    /// Answer matching queries with NXDOMAIN instead of routing them.
    var reject: Bool = false
    var invert: Bool = false

    init(id: UUID = UUID(), name: String = "", serverTag: String = "",
         domains: [String] = [], processNames: [String] = [],
         reject: Bool = false, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.serverTag = serverTag
        self.domains = domains
        self.processNames = processNames
        self.reject = reject
        self.enabled = enabled
    }

    var hasMatcher: Bool {
        !domains.isEmpty || !processNames.isEmpty || !ruleSets.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, enabled, serverTag, domains, processNames, ruleSets
        case reject, invert
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        id = get(.id, UUID())
        name = get(.name, "")
        enabled = get(.enabled, true)
        serverTag = get(.serverTag, "")
        domains = get(.domains, [])
        processNames = get(.processNames, [])
        ruleSets = get(.ruleSets, [])
        reject = get(.reject, false)
        invert = get(.invert, false)
    }
}

/// Everything the resolver needs, as one storable object.
///
/// The defaults are deliberately boring and leak-free: proxied names are
/// resolved by a DoH resolver *through the tunnel*, local names by the system
/// resolver on `direct`, and the bootstrap resolver that turns a server's
/// hostname into an address stays on `direct` so the tunnel can be built in the
/// first place.
struct DNSSettings: Codable, Equatable {

    /// Tags the app creates itself and relies on being present.
    enum Builtin {
        static let remote = "dns-remote"
        static let local = "dns-local"
        static let bootstrap = "dns-bootstrap"
        static let fakeIP = "dns-fakeip"
    }

    var enabled: Bool = true
    var servers: [DNSServerEntry] = DNSSettings.defaultServers()
    var rules: [DNSRule] = DNSSettings.defaultRules()
    /// Server used when nothing matched. Empty = the first server.
    var finalTag: String = Builtin.remote
    /// prefer_ipv4 | prefer_ipv6 | ipv4_only | ipv6_only
    var strategy: String = "prefer_ipv4"
    var disableCache: Bool = false
    var cacheCapacity: Int = 4096
    /// Serve a stale answer while refreshing in the background (sing-box 1.14+).
    var optimistic: Bool = true
    /// Keep an IP → name map so routing rules can still match a domain after
    /// the name was resolved.
    var reverseMapping: Bool = true
    /// Per-query timeout (sing-box 1.14+).
    var timeout: String = "10s"
    /// EDNS client subnet to advertise. Empty = none.
    var clientSubnet: String = ""

    // FakeIP: fast, and it keeps domain information available for routing, but
    // it breaks anything that resolves names itself and connects out of band.
    var fakeIPEnabled: Bool = false
    var fakeIPv4Range: String = "198.18.0.0/15"
    var fakeIPv6Range: String = "fc00::/18"

    static func defaultServers() -> [DNSServerEntry] {
        [
            DNSServerEntry(tag: Builtin.remote, kind: .https,
                           server: "1.1.1.1", path: "/dns-query",
                           detour: ProfileTags.defaultSelector),
            DNSServerEntry(tag: Builtin.local, kind: .local,
                           detour: ProfileTags.direct),
            DNSServerEntry(tag: Builtin.bootstrap, kind: .udp,
                           server: "1.1.1.1", detour: ProfileTags.direct)
        ]
    }

    static func defaultRules() -> [DNSRule] {
        [
            // Names that only mean something on this network. Matched by
            // suffix rather than by a rule-set: there is no published
            // `geosite:private`, and these do not change.
            DNSRule(name: "Local names",
                    serverTag: Builtin.local,
                    domains: ["domain:local", "domain:lan", "domain:internal",
                              "domain:home.arpa", "domain:arpa"])
        ]
    }

    /// The resolver that turns outbound server hostnames into addresses. It has
    /// to sit on `direct`, or bringing the tunnel up would depend on the tunnel
    /// already being up.
    var bootstrapTag: String {
        servers.first { $0.tag == Builtin.bootstrap }?.tag
            ?? servers.first { $0.detour == ProfileTags.direct }?.tag
            ?? servers.first?.tag
            ?? Builtin.local
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, servers, rules, finalTag, strategy, disableCache
        case cacheCapacity, optimistic, reverseMapping, timeout, clientSubnet
        case fakeIPEnabled, fakeIPv4Range, fakeIPv6Range
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        enabled = get(.enabled, true)
        servers = get(.servers, DNSSettings.defaultServers())
        rules = get(.rules, DNSSettings.defaultRules())
        finalTag = get(.finalTag, Builtin.remote)
        strategy = get(.strategy, "prefer_ipv4")
        disableCache = get(.disableCache, false)
        cacheCapacity = get(.cacheCapacity, 4096)
        optimistic = get(.optimistic, true)
        reverseMapping = get(.reverseMapping, true)
        timeout = get(.timeout, "10s")
        clientSubnet = get(.clientSubnet, "")
        fakeIPEnabled = get(.fakeIPEnabled, false)
        fakeIPv4Range = get(.fakeIPv4Range, "198.18.0.0/15")
        fakeIPv6Range = get(.fakeIPv6Range, "fc00::/18")
    }
}
