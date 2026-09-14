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

    func cleanupForUninstall() {
        lock.lock(); defer { lock.unlock() }
        teardown()
    }

    // MARK: - VeilHelperProtocol

    func helperVersion(reply: @escaping (Int) -> Void) {
        reply(VeilHelperInfo.protocolVersion)
    }

    func startTunnel(socksHost: String,
                     socksPort: Int,
                     serverIPs: [String],
                     dnsServers: [String],
                     strictKillSwitch: Bool,
                     protectIPv6: Bool,
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
        guard !servers.isEmpty else {
            return reply("No valid VPN endpoint address was supplied")
        }

        // Already up: this is a server switch, so only re-pin.
        if isTunnelRunning() {
            guard state?.strictKillSwitch == strictKillSwitch,
                  state?.protectsIPv6 == protectIPv6 else {
                return reply("Protection settings changed; reconnect the tunnel")
            }
            return reply(repin(servers) ? nil : "Could not safely re-pin the VPN endpoint")
        }

        let persistedState = state ?? TunnelState.load()
        guard let original = NetworkOps.defaultRoute() else {
            return reply("Could not determine the current default gateway")
        }
        let originalIPv6 = NetworkOps.defaultRoute(ipv6: true)
        log.info("bringing tunnel up on \(self.device, privacy: .public)")

        var newState = TunnelState(device: device,
                                   originalGateway: original.gateway,
                                   originalInterface: original.interface,
                                   originalIPv6Gateway: originalIPv6?.gateway,
                                   originalIPv6Interface: originalIPv6?.interface,
                                   strictKillSwitch: strictKillSwitch,
                                   protectsIPv6: protectIPv6)

        if strictKillSwitch, !NetworkOps.addStrictFallbacks() {
            return reply("Could not enforce the strict IPv4 kill switch")
        }
        if protectIPv6, !NetworkOps.addIPv6Protection() {
            NetworkOps.removeSplitDefaults()
            return reply("Could not enforce strict IPv6 protection")
        }
        guard let process = launchTun2socks(socksHost: socksHost,
                                            socksPort: socksPort,
                                            interface: original.interface) else {
            teardown(state: newState)
            return reply("tun2socks is not installed alongside the helper")
        }
        tun2socks = process
        newState.tun2socksPID = process.processIdentifier

        guard waitForInterface(process) else {
            let detail = lastLogLine().map { ": \($0)" } ?? ""
            process.terminate()
            tun2socks = nil
            teardown(state: newState)
            return reply("\(device) did not come up\(detail)")
        }

        guard NetworkOps.configureInterface(device, address: tunAddress,
                                            peer: tunPeer, mtu: mtu) else {
            process.terminate()
            tun2socks = nil
            teardown(state: newState)
            return reply("Could not configure \(device)")
        }

        if strictKillSwitch {
            let existingToken = persistedState?.pfEnableToken
            let reused = existingToken != nil && NetworkOps.killSwitchIsLoaded()
                && NetworkOps.updateKillSwitch(physicalInterface: original.interface,
                                               tunnelInterface: device,
                                               endpointIPs: servers)
            if !reused, existingToken != nil {
                // The route fallback remains active while a stale PF reference
                // is released and a fresh anchor is installed.
                NetworkOps.disableKillSwitch(token: existingToken)
            }
            let token = reused ? existingToken : NetworkOps.enableKillSwitch(
                physicalInterface: original.interface,
                tunnelInterface: device,
                endpointIPs: servers)
            guard let token else {
                teardown(state: newState)
                return reply("Could not enforce the packet-filter kill switch")
            }
            newState.pfEnableToken = token
        }

        for ip in servers {
            let gateway = HelperValidation.isIPv6(ip) ? originalIPv6?.gateway : original.gateway
            guard let gateway else {
                teardown(state: newState)
                return reply("The VPN endpoint needs IPv6 but no physical IPv6 route is available")
            }
            NetworkOps.deleteHostRoute(ip)
            guard NetworkOps.addHostRoute(ip, gateway: gateway) else {
                teardown(state: newState)
                return reply("Could not pin a VPN endpoint to the physical network")
            }
            newState.pinnedIPs.append(ip)
        }
        guard NetworkOps.addSplitDefaults(gateway: tunGateway, strict: strictKillSwitch) else {
            teardown(state: newState)
            return reply("Could not install all IPv4 tunnel routes")
        }

        if !resolvers.isEmpty {
            for service in NetworkOps.networkServices() {
                newState.savedDNS[service] = NetworkOps.dnsServers(for: service)
                guard NetworkOps.setDNSServers(resolvers, for: service) else {
                    teardown(state: newState)
                    return reply("Could not route DNS for \(service)")
                }
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
        let wanted = HelperValidation.sanitizeAddresses(ips)
        guard !wanted.isEmpty else { return reply("No valid VPN endpoint address was supplied") }
        reply(repin(wanted) ? nil : "Could not safely re-pin the VPN endpoint")
    }

    func addProbeRoutes(_ ips: [String], reply: @escaping (String?) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard var current = state else { return reply("The tunnel is not up") }
        let wanted = HelperValidation.sanitizeAddresses(ips)
        for ip in wanted where !current.pinnedIPs.contains(ip) {
            let gateway = HelperValidation.isIPv6(ip)
                ? current.originalIPv6Gateway
                : current.originalGateway
            guard let gateway else { continue }
            NetworkOps.addHostRoute(ip, gateway: gateway)
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

    func tunnelStatus(reply: @escaping (Bool, String?, Bool, Bool) -> Void) {
        lock.lock(); defer { lock.unlock() }
        let current = state ?? TunnelState.load()
        reply(isTunnelRunning(), current?.device,
              current?.strictKillSwitch == true
                && NetworkOps.hasStrictFallbacks()
                && NetworkOps.killSwitchIsLoaded(),
              current?.protectsIPv6 == true && NetworkOps.hasIPv6Protection())
    }

    // MARK: - Internals

    private func isTunnelRunning() -> Bool {
        guard state != nil else { return false }
        if let process = tun2socks, process.isRunning { return true }
        if let pid = state?.tun2socksPID, pid > 0, kill(pid, 0) == 0,
           NetworkOps.interfaceExists(device) { return true }
        return false
    }

    private func repin(_ ips: [String]) -> Bool {
        guard var current = state, !ips.isEmpty else { return false }
        if let latest = NetworkOps.defaultRoute() {
            current.originalGateway = latest.gateway
            current.originalInterface = latest.interface
        }
        if let latestIPv6 = NetworkOps.defaultRoute(ipv6: true) {
            current.originalIPv6Gateway = latestIPv6.gateway
            current.originalIPv6Interface = latestIPv6.interface
        }
        for ip in ips where !current.pinnedIPs.contains(ip) {
            let gateway = HelperValidation.isIPv6(ip)
                ? current.originalIPv6Gateway
                : current.originalGateway
            guard let gateway, NetworkOps.addHostRoute(ip, gateway: gateway) else { return false }
            current.pinnedIPs.append(ip)
        }
        if current.strictKillSwitch,
           !NetworkOps.updateKillSwitch(physicalInterface: current.originalInterface,
                                        tunnelInterface: device,
                                        endpointIPs: ips) {
            return false
        }
        for oldIP in current.pinnedIPs where !ips.contains(oldIP) && !current.probeIPs.contains(oldIP) {
            NetworkOps.deleteHostRoute(oldIP)
        }
        current.pinnedIPs = ips
        // A switch can leave the split defaults behind if the route table was
        // reshuffled (sleep/wake, Wi-Fi change), so reassert them.
        guard NetworkOps.addSplitDefaults(gateway: tunGateway,
                                          strict: current.strictKillSwitch) else { return false }
        state = current
        current.save()
        return true
    }

    private func launchTun2socks(socksHost: String, socksPort: Int,
                                 interface: String) -> Process? {
        let binary = VeilHelperInfo.tun2socksPath
        guard FileManager.default.isExecutableFile(atPath: binary) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Tun2socksArguments.build(device: device,
                                                     socksHost: socksHost,
                                                     socksPort: socksPort,
                                                     interface: interface)
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

    private func waitForInterface(_ process: Process) -> Bool {
        for _ in 0..<25 {
            if NetworkOps.interfaceExists(device) { return true }
            // A tun2socks that rejected its arguments is already gone; waiting
            // out the full five seconds only delays the error.
            if !process.isRunning { return false }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    /// Last non-empty line tun2socks wrote, so a failure to start says why
    /// instead of only saying that the interface never appeared.
    private func lastLogLine() -> String? {
        guard let data = FileManager.default.contents(atPath: VeilHelperInfo.logPath),
              let text = String(data: data, encoding: .utf8) else { return nil }
        let line = text.split(separator: "\n").last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let line else { return nil }
        return String(line.prefix(300))
    }

    /// Undoes everything recorded in the state, in the reverse order it was
    /// applied. Safe to call when nothing is up.
    private func teardown(state explicitState: TunnelState? = nil,
                          preserveProtection: Bool = false) {
        let current = explicitState ?? state ?? TunnelState.load()

        if preserveProtection, current?.strictKillSwitch == true {
            // Remove only the more-specific active routes. The reject /1s stay
            // installed continuously, so helper recovery creates no leak window.
            NetworkOps.removeActiveTunnelRoutes(strict: true)
            _ = NetworkOps.addStrictFallbacks()
            if current?.protectsIPv6 == true { _ = NetworkOps.addIPv6Protection() }
        } else {
            NetworkOps.disableKillSwitch(token: current?.pfEnableToken)
            NetworkOps.removeSplitDefaults()
            NetworkOps.removeIPv6Protection()
        }

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
        } else if let pid = current?.tun2socksPID, pid > 0,
                  let device = current?.device, NetworkOps.interfaceExists(device) {
            kill(pid, SIGTERM)
        }
        tun2socks = nil
        if preserveProtection, var current {
            current.tun2socksPID = nil
            state = current
            current.save()
        } else {
            state = nil
            TunnelState.clear()
        }
        log.info("tunnel down")
    }

    /// A helper that was killed while a tunnel was up leaves the machine with
    /// no route to the internet. On startup, put it back.
    private func recoverOrphanedTunnel() {
        guard let orphan = TunnelState.load() else { return }
        log.info("recovering orphaned tunnel from a previous run")
        state = orphan
        lock.lock()
        teardown(preserveProtection: orphan.strictKillSwitch)
        lock.unlock()
    }
}
