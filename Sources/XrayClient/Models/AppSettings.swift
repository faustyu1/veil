import Foundation

/// How traffic is captured.
enum TunnelMode: String, Codable, CaseIterable, Identifiable {
    case systemProxy   // SOCKS/HTTP system proxy (no admin, browsers only)
    case tun           // full-traffic TUN via tun2socks (needs admin)

    var id: String { rawValue }
    var title: String {
        switch self {
        case .systemProxy: return "System Proxy"
        case .tun:         return "TUN (All Apps)"
        }
    }
    var subtitle: String {
        switch self {
        case .systemProxy: return "Browsers & proxy-aware apps. No password needed."
        case .tun:         return "All traffic incl. Telegram, terminal, games. Asks for password."
        }
    }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

/// Verbosity of the bundled Xray core's log output.
enum LogLevel: String, Codable, CaseIterable, Identifiable {
    case debug, info, warning, error, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .debug:   return "Debug"
        case .info:    return "Info"
        case .warning: return "Warning"
        case .error:   return "Error"
        case .none:    return "None"
        }
    }
}


/// User-facing settings, persisted alongside subscriptions.
struct AppSettings: Codable, Equatable {
    var mode: TunnelMode = .systemProxy
    var appearance: AppAppearance = .system
    var language: AppLanguage = .system
    var autoUpdateSubscriptions: Bool = true
    var autoUpdateIntervalHours: Int = 12

    /// Intervals offered for `autoUpdateIntervalHours`, in hours.
    ///
    /// A list beats the stepper this replaced: the old control moved one hour
    /// at a time between 1 and 168, so reaching a day meant twenty-four hits on
    /// an arrow a few pixels tall. `current` is folded in so a value an earlier
    /// build stored — or one set from the control API — is still selectable
    /// rather than being snapped to the nearest preset the first time Settings
    /// is opened.
    static func autoUpdateIntervalChoices(including current: Int) -> [Int] {
        let presets = [1, 3, 6, 12, 24, 48, 168]
        guard current > 0, !presets.contains(current) else { return presets }
        return (presets + [current]).sorted()
    }
    var closeToTray: Bool = true            // red button hides to menu bar
    var socksPort: Int = 10808
    var httpPort: Int = 10809
    var lastSelectedServerID: UUID?
    var logLevel: LogLevel = .warning

    // Routing
    var routingPreset: RoutingPreset = .bypassLAN
    var customRules: [RoutingRule] = []
    var blockAds: Bool = false
    var geoSource: GeoAssetSource = .loyalsoldier
    var customGeoipURL: String = ""
    var customGeositeURL: String = ""

    // Routing v2 — the outbound graph. Groups are named sets of servers that
    // behave like one outbound, so a rule can send an app through a specific
    // group instead of through "the proxy".
    var serverGroups: [ServerGroup] = []
    /// Rule-sets the user added by hand. The ones implied by `geosite:` /
    /// `geoip:` entries are derived at build time and need no storage.
    var ruleSets: [RuleSetRef] = []

    /// Community rule lists the user turned on, by `CommunityList.id`. Only
    /// the ids live here; the lists themselves are cached on disk by
    /// `CommunityListManager`, because they are bulk data that can be fetched
    /// again at any time.
    var communityLists: [String] = []
    /// Where a match in one of those lists goes. Selecting a list normally
    /// means "send this through the tunnel", which is what `.proxy` does.
    var communityListTarget: RuleTarget = .proxy

    // Resolver
    var dns = DNSSettings()

    // sing-box TUN. Process-aware rules only work when sing-box owns the
    // interface, so the native inbound is the default and tun2socks is the
    // fallback for anyone who hits a problem with it.
    var useNativeTun: Bool = true
    var tunStrictRoute: Bool = false
    var tunStack: String = ""

    // Local control API (Clash-compatible, served by sing-box).
    var controlAPIEnabled: Bool = true
    var controlAPIPort: Int = 9090

    // Veil's own control API: read and write the routing configuration from
    // outside the app. Off by default — it can change where the machine's
    // traffic goes, so it is turned on deliberately or not at all.
    var veilAPIEnabled: Bool = false
    var veilAPIPort: Int = 9091

    // Startup
    var autoConnectOnLaunch: Bool = false
    var launchAtLogin: Bool = false

    // Notifications
    var notifyOnConnect: Bool = false

    // Subscription
    var sendHwid: Bool = true
    /// Overrides the User-Agent sent with subscription requests. Empty means
    /// the default one. Panels with custom Response Rules key off it.
    var userAgentOverride: String = ""

    // Tunnel shape. Only the iOS build reads these — there the whole tunnel is
    // Xray's own layer-3 inbound behind NetworkExtension, so the interface MTU,
    // the address families we claim and the resolver are ours to pick.
    var tunnelMTU: Int = 1500
    var ipv6Enabled: Bool = true
    var dnsServers: [String] = ["1.1.1.1", "8.8.8.8"]

    init() {}

    /// Resilient decoding: any missing key falls back to its default so old
    /// `store.json` files (with fewer/older fields) still load cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        mode = get(.mode, .systemProxy)
        appearance = get(.appearance, .system)
        language = get(.language, .system)
        autoUpdateSubscriptions = get(.autoUpdateSubscriptions, true)
        autoUpdateIntervalHours = get(.autoUpdateIntervalHours, 12)
        closeToTray = get(.closeToTray, true)
        socksPort = get(.socksPort, 10808)
        httpPort = get(.httpPort, 10809)
        lastSelectedServerID = try? c.decode(UUID.self, forKey: .lastSelectedServerID)
        logLevel = get(.logLevel, .warning)
        routingPreset = get(.routingPreset, .bypassLAN)
        customRules = get(.customRules, [])
        blockAds = get(.blockAds, false)
        geoSource = get(.geoSource, .loyalsoldier)
        customGeoipURL = get(.customGeoipURL, "")
        customGeositeURL = get(.customGeositeURL, "")
        serverGroups = get(.serverGroups, [])
        ruleSets = get(.ruleSets, [])
        communityLists = get(.communityLists, [])
        communityListTarget = get(.communityListTarget, .proxy)
        dns = get(.dns, DNSSettings())
        useNativeTun = get(.useNativeTun, true)
        tunStrictRoute = get(.tunStrictRoute, false)
        tunStack = get(.tunStack, "")
        controlAPIEnabled = get(.controlAPIEnabled, true)
        controlAPIPort = get(.controlAPIPort, 9090)
        veilAPIEnabled = get(.veilAPIEnabled, false)
        veilAPIPort = get(.veilAPIPort, 9091)
        autoConnectOnLaunch = get(.autoConnectOnLaunch, false)
        launchAtLogin = get(.launchAtLogin, false)
        notifyOnConnect = get(.notifyOnConnect, false)
        sendHwid = get(.sendHwid, true)
        userAgentOverride = get(.userAgentOverride, "")
        tunnelMTU = get(.tunnelMTU, 1500)
        ipv6Enabled = get(.ipv6Enabled, true)
        dnsServers = get(.dnsServers, ["1.1.1.1", "8.8.8.8"])
    }

    /// DNS servers to hand the tunnel, never empty — an empty resolver list
    /// would leave the device with no way to resolve anything at all.
    var effectiveDNSServers: [String] {
        let cleaned = dnsServers
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? ["1.1.1.1", "8.8.8.8"] : cleaned
    }

    /// The ordered routing rules to feed Xray, derived from the active preset
    /// (or the user's custom list).
    var effectiveRoutingRules: [RoutingRule] {
        // The user's own rules apply under every preset, not only "Custom" —
        // wanting one application on a particular server is no reason to give
        // up the preset's bypasses. They sit between the guards, which have to
        // win, and the preset's country rules, which must not.
        routingPreset.guardRules(blockAds: blockAds)
            + customRules
            + CommunityListManager.rules(for: self)
            + routingPreset.presetRules()
    }
}

