// macOS-only: this file drives TUN mode through the privileged helper. The iOS
// build runs Xray in-process inside the NetworkExtension instead (see
// ios/Tunnel) and needs none of it.
#if os(macOS)
import Foundation
import VeilHelperKit

/// Drives TUN (full-traffic) mode.
///
/// Nothing here runs as root. Route, DNS and `tun2socks` changes are requests
/// sent to the Veil helper — a launchd daemon that accepts a fixed set of typed
/// commands from this app and nothing else. Installing it is one admin prompt,
/// once; there is no sudoers rule and no root-owned shell script.
enum TunManager {

    enum TunError: LocalizedError {
        case missingResource(String)
        case scriptFailed(String)
        case installFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingResource(let r): return "Missing bundled resource: \(r)"
            case .scriptFailed(let m):    return "TUN command failed: \(m)"
            case .installFailed(let m):   return "Helper install failed: \(m)"
            }
        }
    }

    /// Resolvers handed to the system while the tunnel is up. They are queried
    /// through the tunnel, so they must not be the ISP's.
    static let defaultTunnelDNS = ["1.1.1.1", "1.0.0.1"]

    // MARK: - Helper installation

    /// True when the helper is installed, reachable, and speaks this build's
    /// protocol version.
    static var isHelperInstalled: Bool { PrivilegedHelper.isReady }

    /// Installs (or upgrades) the helper. Shows ONE macOS admin prompt.
    ///
    /// The installer also pins this exact app binary as the only client the
    /// helper will talk to, so it has to run again after the app is rebuilt or
    /// updated — an ad-hoc signature has no stable identity to pin instead.
    static func installHelper() throws {
        guard let payload = PrivilegedHelper.bundledPayloadDirectory else {
            throw TunError.missingResource("Contents/Library/VeilHelper")
        }
        let installer = payload.appendingPathComponent("install-daemon.sh")
        guard FileManager.default.fileExists(atPath: installer.path) else {
            throw TunError.missingResource("install-daemon.sh")
        }
        do {
            try runAsAdmin(["/bin/bash", installer.path,
                            payload.path, Bundle.main.bundleURL.path])
        } catch {
            throw TunError.installFailed(error.localizedDescription)
        }
    }

    /// Removes the helper, its payload and any leftovers from the old
    /// sudoers-based install (one admin prompt).
    static func uninstallHelper() {
        guard let payload = PrivilegedHelper.bundledPayloadDirectory else { return }
        let uninstaller = payload.appendingPathComponent("uninstall-daemon.sh")
        guard FileManager.default.fileExists(atPath: uninstaller.path) else { return }
        try? runAsAdmin(["/bin/bash", uninstaller.path])
    }

    // MARK: - Up / Down

    /// Brings TUN up, installing the helper first if needed.
    static func up(socksAddr: String,
                   serverIPs: [String],
                   dnsServers: [String] = defaultTunnelDNS) throws {
        if !isHelperInstalled {
            try installHelper()
        }
        guard let (host, port) = splitAddress(socksAddr) else {
            throw TunError.scriptFailed("Malformed SOCKS address: \(socksAddr)")
        }
        try PrivilegedHelper.startTunnel(socksHost: host, socksPort: port,
                                         serverIPs: serverIPs,
                                         dnsServers: dnsServers)
    }

    /// Tears TUN down. Best-effort.
    static func down() {
        try? PrivilegedHelper.stopTunnel()
    }

    // MARK: - Native core (sing-box owns the interface)

    /// Hands the whole profile to the helper, which runs sing-box as root.
    ///
    /// Unlike `up`, nothing here pins routes or rewrites DNS: the core brings
    /// up its own interface and installs its own routes. That is the point —
    /// with tun2socks in front, the PID behind a connection is lost before
    /// routing happens, so no process rule could ever match.
    static func startNativeCore(config: Data) throws {
        if !isHelperInstalled {
            try installHelper()
        }
        try PrivilegedHelper.startCore(config: config)
    }

    /// Replaces the running core's configuration — a server switch, a rule
    /// change, anything that alters the profile.
    static func reloadNativeCore(config: Data) throws {
        guard isHelperInstalled else { return try startNativeCore(config: config) }
        try PrivilegedHelper.reloadCore(config: config)
    }

    static func stopNativeCore() {
        try? PrivilegedHelper.stopCore()
    }

    /// Whether the helper says the core is up, and the tail of its log.
    static var nativeCoreStatus: (running: Bool, log: String?) {
        PrivilegedHelper.coreStatus()
    }

    /// Whether the helper says a tunnel is up right now.
    static var looksActive: Bool { PrivilegedHelper.tunnelIsUp }

    /// Cleans up a tunnel left behind by a crash or a force-quit.
    static func emergencyCleanup() {
        guard PrivilegedHelper.isInstalled else { return }
        if PrivilegedHelper.coreStatus().running { stopNativeCore() }
        guard PrivilegedHelper.tunnelIsUp else { return }
        down()
    }

    /// Temporarily route server IPs via the physical gateway so latency probes
    /// bypass the tunnel. Best-effort; no-op when the tunnel is not up.
    static func pingRouteAdd(_ ips: [String]) {
        guard !ips.isEmpty else { return }
        try? PrivilegedHelper.addProbeRoutes(ips)
    }

    /// Removes the temporary probe host-routes.
    static func pingRouteDel() {
        try? PrivilegedHelper.removeProbeRoutes()
    }

    // MARK: - Server IP resolution

    /// Resolves a host to IPv4 addresses. IP literals pass through unchanged.
    static func resolveIPs(host: String) -> [String] {
        if HelperValidation.isIPv4(host) { return [host] }
        var results: [String] = []
        var hints = addrinfo(ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_STREAM,
                             ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil,
                             ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0 else { return results }
        defer { freeaddrinfo(info) }
        var ptr = info
        while let node = ptr {
            if let sa = node.pointee.ai_addr {
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                    var addr = sin.pointee.sin_addr
                    inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN))
                }
                let ip = String(cString: buf)
                if !ip.isEmpty, !results.contains(ip) { results.append(ip) }
            }
            ptr = node.pointee.ai_next
        }
        return results
    }

    // MARK: - Internals

    /// Splits `127.0.0.1:10808` into its parts.
    static func splitAddress(_ address: String) -> (host: String, port: Int)? {
        guard let separator = address.lastIndex(of: ":") else { return nil }
        let host = String(address[address.startIndex..<separator])
        guard let port = Int(address[address.index(after: separator)...]),
              HelperValidation.isPort(port), !host.isEmpty else { return nil }
        return (host, port)
    }

    /// Runs the installer as root via AppleScript's admin prompt. This is the
    /// only place the app asks for a password, and the only thing it ever runs
    /// this way is one of its own two bundled installer scripts.
    private static func runAsAdmin(_ argv: [String]) throws {
        let command = argv
            .map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
            .joined(separator: " ")
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", appleScript]
        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit \(proc.terminationStatus)"
            throw TunError.scriptFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
#endif
