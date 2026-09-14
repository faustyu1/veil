import Foundation
import VeilHelperKit
import os

/// The privileged side of Veil. Runs as root under launchd and answers a fixed
/// set of typed requests — it never receives a command, a path or a script.
///
/// Every method validates its input, does the work synchronously and replies
/// before returning: XPC gives each call its own queue, so there is no thread
/// hop to get wrong and the lock below is the only shared-state discipline
/// needed.
final class HelperService: NSObject, VeilHelperProtocol, @unchecked Sendable {

    private let log = Logger(subsystem: "dev.local.veil.helper", category: "tunnel")
    private let lock = NSLock()

    private let device = "utun123"
    private let tunAddress = "198.18.0.1"
    private let tunPeer = "198.18.0.2"
    private let tunGateway = "198.18.0.1"
    private let mtu = 1500

    private var state: TunnelState?
    private var tun2socks: Process?

    override init() {
        super.init()
        recoverOrphanedTunnel()
    }

    // MARK: - VeilHelperProtocol

    func helperVersion(reply: @escaping (Int) -> Void) {
        reply(VeilHelperInfo.protocolVersion)
    }

    func startTunnel(socksHost: String,
                     socksPort: Int,
                     serverIPs: [String],
                     dnsServers: [String],
                     reply: @escaping (String?) -> Void) {
        lock.lock(); defer { lock.unlock() }

        guard HelperValidation.isLoopback(socksHost) else {
            return reply("SOCKS host must be the loopback address")
        }
        guard HelperValidation.isPort(socksPort) else {
            return reply("SOCKS port out of range")
        }
        let servers = HelperValidation.sanitizeAddresses(serverIPs)
        let resolvers = HelperValidation.sanitizeResolvers(dnsServers)

        // Already up: this is a server switch, so only re-pin.
        if isTunnelRunning() {
            repin(servers)
            return reply(nil)
        }

        guard let original = NetworkOps.defaultRoute() else {
            return reply("Could not determine the current default gateway")
        }
        log.info("bringing tunnel up on \(self.device, privacy: .public)")

        var newState = TunnelState(device: device,
                                   originalGateway: original.gateway,
                                   originalInterface: original.interface)

        guard let process = launchTun2socks(socksHost: socksHost,
                                            socksPort: socksPort,
                                            interface: original.interface) else {
            return reply("tun2socks is not installed alongside the helper")
        }
        tun2socks = process
        newState.tun2socksPID = process.processIdentifier

        guard waitForInterface() else {
            process.terminate()
            tun2socks = nil
            return reply("\(device) did not come up")
        }

        guard NetworkOps.configureInterface(device, address: tunAddress,
                                            peer: tunPeer, mtu: mtu) else {
            process.terminate()
            tun2socks = nil
            return reply("Could not configure \(device)")
        }

        for ip in servers {
            NetworkOps.deleteHostRoute(ip)
            NetworkOps.addHostRoute(ip, gateway: original.gateway)
        }
        newState.pinnedIPs = servers
        NetworkOps.addSplitDefaults(gateway: tunGateway)

        if !resolvers.isEmpty {
            for service in NetworkOps.networkServices() {
                newState.savedDNS[service] = NetworkOps.dnsServers(for: service)
                NetworkOps.setDNSServers(resolvers, for: service)
            }
        }

        state = newState
        newState.save()
        log.info("tunnel up, pinned \(servers.count, privacy: .public) server address(es)")
        reply(nil)
    }

    func stopTunnel(reply: @escaping (String?) -> Void) {
        lock.lock(); defer { lock.unlock() }
        teardown()
        reply(nil)
    }

    func pinServerIPs(_ ips: [String], reply: @escaping (String?) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard state != nil else { return reply("The tunnel is not up") }
        repin(HelperValidation.sanitizeAddresses(ips))
        reply(nil)
    }

    func addProbeRoutes(_ ips: [String], reply: @escaping (String?) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard var current = state else { return reply("The tunnel is not up") }
        let wanted = HelperValidation.sanitizeAddresses(ips)
        for ip in wanted where !current.pinnedIPs.contains(ip) {
            NetworkOps.addHostRoute(ip, gateway: current.originalGateway)
            if !current.probeIPs.contains(ip) { current.probeIPs.append(ip) }
        }
        state = current
        current.save()
        reply(nil)
    }

    func removeProbeRoutes(reply: @escaping (String?) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard var current = state else { return reply(nil) }
        for ip in current.probeIPs { NetworkOps.deleteHostRoute(ip) }
        current.probeIPs = []
        state = current
        current.save()
        reply(nil)
    }

    func tunnelStatus(reply: @escaping (Bool, String?) -> Void) {
        lock.lock(); defer { lock.unlock() }
        reply(isTunnelRunning(), state?.device)
    }

    // MARK: - Internals

    private func isTunnelRunning() -> Bool {
        guard state != nil else { return false }
        if let process = tun2socks, process.isRunning { return true }
        if let pid = state?.tun2socksPID, pid > 0, kill(pid, 0) == 0 { return true }
        return false
    }

    private func repin(_ ips: [String]) {
        guard var current = state else { return }
        for ip in ips where !current.pinnedIPs.contains(ip) {
            NetworkOps.addHostRoute(ip, gateway: current.originalGateway)
            current.pinnedIPs.append(ip)
        }
        // A switch can leave the split defaults behind if the route table was
        // reshuffled (sleep/wake, Wi-Fi change), so reassert them.
        NetworkOps.addSplitDefaults(gateway: tunGateway)
        state = current
        current.save()
    }

    private func launchTun2socks(socksHost: String, socksPort: Int,
                                 interface: String) -> Process? {
        let binary = VeilHelperInfo.tun2socksPath
        guard FileManager.default.isExecutableFile(atPath: binary) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = [
            "-device", device,
            "-proxy", "socks5://\(socksHost):\(socksPort)",
            "-interface", interface,
        ]
        // The log lives next to the helper (root-owned, 0600) rather than in
        // /tmp, where anything could read or pre-create it.
        let logPath = VeilHelperInfo.logPath
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil,
                                           attributes: [.posixPermissions: 0o600])
        }
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            process.standardOutput = handle
            process.standardError = handle
        }
        do {
            try process.run()
            return process
        } catch {
            log.error("tun2socks failed to start: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func waitForInterface() -> Bool {
        for _ in 0..<25 {
            if NetworkOps.interfaceExists(device) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    /// Undoes everything recorded in the state, in the reverse order it was
    /// applied. Safe to call when nothing is up.
    private func teardown() {
        let current = state ?? TunnelState.load()

        NetworkOps.removeSplitDefaults()

        if let current {
            for ip in current.pinnedIPs + current.probeIPs {
                NetworkOps.deleteHostRoute(ip)
            }
            for (service, servers) in current.savedDNS {
                NetworkOps.setDNSServers(servers, for: service)
            }
        }

        if let process = tun2socks, process.isRunning {
            process.terminate()
        } else if let pid = current?.tun2socksPID, pid > 0 {
            kill(pid, SIGTERM)
        }
        tun2socks = nil
        state = nil
        TunnelState.clear()
        log.info("tunnel down")
    }

    /// A helper that was killed while a tunnel was up leaves the machine with
    /// no route to the internet. On startup, put it back.
    private func recoverOrphanedTunnel() {
        guard let orphan = TunnelState.load() else { return }
        log.info("recovering orphaned tunnel from a previous run")
        state = orphan
        lock.lock()
        teardown()
        lock.unlock()
    }
}
