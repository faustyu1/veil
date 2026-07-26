import Foundation

/// Wire format for `NETunnelProviderSession.sendProviderMessage`.
///
/// The app never talks to Xray directly — the core only ever runs inside the
/// extension. Everything the UI shows (state, traffic counters, core log) comes
/// back through these messages.
enum TunnelCommand: String, Codable {
    /// Current core state + counters + log tail.
    case status
    /// Re-read the config file and restart the core without dropping the
    /// tunnel. This is how switching servers stays sub-second: the utun stays
    /// up, iOS never shows a reconnect, only Xray restarts.
    case reload
    /// Truncate the core log.
    case clearLog
}

struct TunnelRequest: Codable {
    var command: TunnelCommand

    init(_ command: TunnelCommand) { self.command = command }

    func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

    static func decode(_ data: Data) -> TunnelRequest? {
        try? JSONDecoder().decode(TunnelRequest.self, from: data)
    }
}

struct TunnelStatus: Codable {
    var running: Bool = false
    var coreVersion: String = ""
    var serverName: String = ""
    var uplinkBytes: Int64 = 0
    var downlinkBytes: Int64 = 0
    var startedAt: Date?
    var lastError: String?
    /// Tail of the core log, capped so provider messages stay small.
    var log: String = ""

    func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

    static func decode(_ data: Data) -> TunnelStatus? {
        try? JSONDecoder().decode(TunnelStatus.self, from: data)
    }
}

/// Everything the provider needs that isn't in the Xray config itself. Written
/// next to the config by the app, read by the extension on start and on reload.
struct TunnelSession: Codable {
    var serverName: String = ""
    /// Only used to populate `tunnelRemoteAddress`; routing is Xray's job.
    var serverAddress: String = "127.0.0.1"
    var mtu: Int = 1500
    /// Advertise IPv6 inside the tunnel. On by default: if we only claim IPv4,
    /// IPv6-capable apps route around the tunnel and leak.
    var ipv6Enabled: Bool = true
    var dnsServers: [String] = ["1.1.1.1", "8.8.8.8"]
    /// Hard cap on the Go heap. NetworkExtension processes get a small memory
    /// budget and are killed outright when they exceed it.
    var maxMemoryMB: Int = 48

    func write() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: AppGroup.sessionURL, options: .atomic)
    }

    static func load() -> TunnelSession {
        guard let data = try? Data(contentsOf: AppGroup.sessionURL),
              let session = try? JSONDecoder().decode(TunnelSession.self, from: data) else {
            return TunnelSession()
        }
        return session
    }
}
