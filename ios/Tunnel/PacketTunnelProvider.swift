import Foundation
import NetworkExtension
import Network
import os

import XrayCore

/// The whole VPN. NetworkExtension creates a utun interface for us and hands
/// over its file descriptor; we give that descriptor to Xray-core, whose native
/// layer-3 `tun` inbound terminates TCP/UDP off the wire with its own gVisor
/// stack and dispatches every connection through the configured outbound.
///
/// There is no tun2socks, no local SOCKS hop and no second core: the packet
/// path is utun -> Xray -> server, entirely in this process.
///
/// Concurrency: NetworkExtension calls in on several queues, so every piece of
/// mutable state below is confined to `stateQueue`. Methods whose names end in
/// `Locked` must already be running on it.
final class PacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {

    private let log = Logger(subsystem: "dev.local.veil", category: "tunnel")
    private let stateQueue = DispatchQueue(label: "dev.local.veil.tunnel.state")

    private var session = TunnelSession()
    private var startedAt: Date?
    private var lastError: String?
    /// Descriptor of the utun NetworkExtension gave us. Owned by the system —
    /// we hand it to Xray but never close it.
    private var tunFileDescriptor: Int32 = -1

    private var pathMonitor: NWPathMonitor?
    private var restartWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    override func startTunnel(options: [String: NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        let completion = UncheckedSendable(completionHandler)
        Task {
            do {
                try? FileManager.default.removeItem(at: AppGroup.lastErrorURL)

                let session = TunnelSession.load()
                let configJSON = try TunnelConfigWriter.loadConfig()

                try await setTunnelNetworkSettings(Self.makeNetworkSettings(session))

                // The utun only exists once the settings are applied, so look
                // for it here rather than at the top of startTunnel.
                guard let fd = Self.findUtunDescriptor() else {
                    throw TunnelError.noTunDescriptor
                }
                log.info("utun descriptor: \(fd, privacy: .public)")

                try stateQueue.sync {
                    self.session = session
                    self.tunFileDescriptor = fd
                    try self.startCoreLocked(configJSON: configJSON, truncateLog: true)
                    self.startedAt = Date()
                }

                startPathMonitor()
                completion.value(nil)
            } catch {
                stateQueue.sync { self.lastError = error.localizedDescription }
                // This process is about to be torn down, so leave the reason
                // somewhere the app can still find it.
                try? Data(error.localizedDescription.utf8)
                    .write(to: AppGroup.lastErrorURL, options: .atomic)
                log.error("startTunnel failed: \(error.localizedDescription, privacy: .public)")
                completion.value(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        log.info("stopTunnel: \(reason.rawValue, privacy: .public)")
        stopPathMonitor()
        stateQueue.sync {
            stopCoreLocked()
            startedAt = nil
            tunFileDescriptor = -1
        }
        completionHandler()
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Nothing to flush — Xray owns its connections. Just make sure a
        // pending restart doesn't fire while the device is asleep.
        stateQueue.sync {
            restartWorkItem?.cancel()
            restartWorkItem = nil
        }
        completionHandler()
    }

    override func wake() {
        // The link almost certainly changed underneath us; rebuild it.
        scheduleCoreRestart(reason: "wake", after: 1.0)
    }

    // MARK: - Core control

    /// - Parameter truncateLog: only true for a fresh tunnel. A restart caused
    ///   by a network change would otherwise wipe the very lines explaining why
    ///   it happened.
    private func startCoreLocked(configJSON: String, truncateLog: Bool) throws {
        var error: NSError?
        if truncateLog {
            XrayPrepareLog(AppGroup.logURL.path, &error)
        }

        error = nil
        let started = XrayStart(configJSON,
                                Int(tunFileDescriptor),
                                AppGroup.geoDirectory.path,
                                session.maxMemoryMB,
                                &error)
        guard started else {
            throw error ?? TunnelError.coreStartFailed("unknown")
        }
        lastError = nil
        log.info("xray \(XrayVersion(), privacy: .public) running")
    }

    private func stopCoreLocked() {
        var error: NSError?
        XrayStop(&error)
        if let error {
            log.error("xray stop: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Restarts Xray against the current config file while keeping the tunnel
    /// (and its descriptor) up. Used both for switching servers and for
    /// recovering from a network change.
    private func restartCoreLocked(reason: String) {
        guard tunFileDescriptor >= 0 else { return }
        log.info("restarting core: \(reason, privacy: .public)")
        reasserting = true
        defer { reasserting = false }

        stopCoreLocked()
        do {
            session = TunnelSession.load()
            let configJSON = try TunnelConfigWriter.loadConfig()
            try startCoreLocked(configJSON: configJSON, truncateLog: false)
            if startedAt == nil { startedAt = Date() }
        } catch {
            lastError = error.localizedDescription
            log.error("restart failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Network settings

    private static func makeNetworkSettings(_ session: TunnelSession) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: session.serverAddress)
        settings.mtu = NSNumber(value: session.mtu)

        // Benchmark/test-network range: no home or carrier network uses it, so
        // the interface address can never collide with the physical one.
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        if session.ipv6Enabled {
            let ipv6 = NEIPv6Settings(addresses: ["fd6e:a81b:704f:1211::1"],
                                      networkPrefixLengths: [64])
            ipv6.includedRoutes = [NEIPv6Route.default()]
            settings.ipv6Settings = ipv6
        }

        let dns = NEDNSSettings(servers: session.dnsServers)
        // Empty match domain = "resolve everything through us", which is what
        // sends the queries into the tunnel where Xray's DNS outbound answers.
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        return settings
    }

    // MARK: - utun discovery

    /// Finds the descriptor of the utun socket NetworkExtension opened for this
    /// provider. There is no API for it, but that socket answers
    /// `getsockopt(SYSPROTO_CONTROL, UTUN_OPT_IFNAME)` with its interface name,
    /// which nothing else in the process does.
    private static func findUtunDescriptor() -> Int32? {
        let sysprotoControl: Int32 = 2
        let utunOptIfname: Int32 = 2
        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))

        for fd in Int32(0)...1024 {
            var length = socklen_t(name.count)
            guard getsockopt(fd, sysprotoControl, utunOptIfname, &name, &length) == 0 else {
                continue
            }
            let bytes = name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            if String(decoding: bytes, as: UTF8.self).hasPrefix("utun") { return fd }
        }
        return nil
    }

    // MARK: - Path monitoring

    /// Wi-Fi <-> cellular handovers invalidate every socket Xray holds. iOS
    /// keeps the utun alive across them, so all we have to do is rebuild the
    /// core's connections — debounced, because one handover produces a burst of
    /// path updates.
    private func startPathMonitor() {
        stopPathMonitor()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            self?.scheduleCoreRestart(reason: "network change", after: 1.5)
        }
        monitor.start(queue: stateQueue)
        stateQueue.sync { pathMonitor = monitor }
    }

    private func stopPathMonitor() {
        stateQueue.sync {
            restartWorkItem?.cancel()
            restartWorkItem = nil
            pathMonitor?.cancel()
            pathMonitor = nil
        }
    }

    private func scheduleCoreRestart(reason: String, after delay: TimeInterval) {
        stateQueue.async { [self] in
            restartWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.restartCoreLocked(reason: reason)
            }
            restartWorkItem = work
            stateQueue.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    // MARK: - App messages

    override func handleAppMessage(_ messageData: Data,
                                   completionHandler: ((Data?) -> Void)?) {
        guard let request = TunnelRequest.decode(messageData) else {
            completionHandler?(nil)
            return
        }

        let completion = UncheckedSendable(completionHandler)
        stateQueue.async { [self] in
            switch request.command {
            case .status:
                break
            case .reload:
                // Server switch: same tunnel, same descriptor, new outbound.
                restartWorkItem?.cancel()
                restartWorkItem = nil
                restartCoreLocked(reason: "config reload")
            case .clearLog:
                var error: NSError?
                XrayPrepareLog(AppGroup.logURL.path, &error)
            }
            completion.value?(currentStatusLocked().encoded())
        }
    }

    private func currentStatusLocked() -> TunnelStatus {
        TunnelStatus(running: XrayIsRunning(),
                     coreVersion: XrayVersion(),
                     serverName: session.serverName,
                     uplinkBytes: XrayUplink(),
                     downlinkBytes: XrayDownlink(),
                     startedAt: startedAt,
                     lastError: lastError,
                     log: Self.logTail())
    }

    /// Last few KB of the core log. Provider messages travel over XPC, so we
    /// keep the payload small rather than shipping the whole file.
    private static func logTail(maxBytes: Int = 16_000) -> String {
        guard let handle = try? FileHandle(forReadingFrom: AppGroup.logURL) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let offset = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: offset)
        let data = (try? handle.readToEnd()) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}

/// Escape hatch for NetworkExtension's completion handlers: they are plain
/// non-`@Sendable` closures, but Apple documents them as callable from any
/// thread, so boxing them is the honest way to move them across a queue hop.
private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

enum TunnelError: LocalizedError {
    case noTunDescriptor
    case coreStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .noTunDescriptor:
            return "Could not find the tunnel interface descriptor."
        case .coreStartFailed(let message):
            return "Xray failed to start: \(message)"
        }
    }
}
