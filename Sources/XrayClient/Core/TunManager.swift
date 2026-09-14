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
            try runVerifiedScriptAsAdmin(installer, payload: payload,
                                         appBundle: Bundle.main.bundleURL)
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
        try? runVerifiedScriptAsAdmin(uninstaller, payload: payload,
                                      appBundle: Bundle.main.bundleURL)
    }

    // MARK: - Up / Down

    /// Brings TUN up, installing the helper first if needed.
    static func up(socksAddr: String,
                   serverIPs: [String],
                   dnsServers: [String] = defaultTunnelDNS,
                   strictKillSwitch: Bool = true,
                   protectIPv6: Bool = true) throws {
        if !isHelperInstalled {
            try installHelper()
        }
        guard let (host, port) = splitAddress(socksAddr) else {
            throw TunError.scriptFailed("Malformed SOCKS address: \(socksAddr)")
        }
        try PrivilegedHelper.startTunnel(socksHost: host, socksPort: port,
                                         serverIPs: serverIPs,
                                         dnsServers: dnsServers,
                                         strictKillSwitch: strictKillSwitch,
                                         protectIPv6: protectIPv6)
    }

    /// Tears TUN down. Best-effort.
    static func down() {
        try? PrivilegedHelper.stopTunnel()
    }

    /// Whether the helper says a tunnel is up right now.
    static var looksActive: Bool { PrivilegedHelper.tunnelIsUp }

    /// Cleans up a tunnel left behind by a crash or a force-quit.
    static func emergencyCleanup() {
        guard PrivilegedHelper.isInstalled, PrivilegedHelper.tunnelIsUp else { return }
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

    /// Resolves a host to IPv4 and IPv6 addresses. IP literals pass through unchanged.
    static func resolveIPs(host: String) -> [String] {
        if HelperValidation.isIPv4(host) || HelperValidation.isIPv6(host) { return [host] }
        var results: [String] = []
        var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM,
                             ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil,
                             ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0 else { return results }
        defer { freeaddrinfo(info) }
        var ptr = info
        while let node = ptr {
            if let sa = node.pointee.ai_addr,
               sa.pointee.sa_family == AF_INET || sa.pointee.sa_family == AF_INET6 {
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                guard getnameinfo(sa, node.pointee.ai_addrlen,
                                  &buf, socklen_t(buf.count), nil, 0,
                                  NI_NUMERICHOST) == 0 else {
                    ptr = node.pointee.ai_next
                    continue
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
    private static func runVerifiedScriptAsAdmin(_ script: URL, payload: URL,
                                                 appBundle: URL) throws {
        let allowed = ["install-daemon.sh", "uninstall-daemon.sh"]
        guard allowed.contains(script.lastPathComponent),
              script.deletingLastPathComponent().standardizedFileURL == payload.standardizedFileURL else {
            throw TunError.scriptFailed("Refusing an unexpected privileged script")
        }

        // This bootstrap is compiled into the signed app. Root verifies the app,
        // copies the requested signed-manifest script to a root-only file, checks
        // the copy, and only then executes it. The mutable bundle path is never
        // directly interpreted as root shell code.
        let bootstrap = #"""
set -euo pipefail
app="$1"; payload="$2"; name="$3"
case "$name" in install-daemon.sh|uninstall-daemon.sh) ;; *) exit 64 ;; esac
/usr/bin/codesign --verify --deep --strict "$app"
manifest="$payload/payload.sha256"
expected=$(/usr/bin/awk -v n="$name" '$2 == n || $2 == "*" n { print $1 }' "$manifest")
[ "${#expected}" -eq 64 ]
tmp=$(/usr/bin/mktemp "/var/tmp/veil-bootstrap.XXXXXX")
trap '/bin/rm -f "$tmp"' EXIT
/usr/bin/install -m 0700 -o root -g wheel "$payload/$name" "$tmp"
actual=$(/usr/bin/shasum -a 256 "$tmp" | /usr/bin/awk '{print $1}')
[ "$actual" = "$expected" ]
/bin/bash "$tmp" "$payload" "$app"
"""#

        let argv = ["/bin/bash", "-c", bootstrap, "veil-bootstrap",
                    appBundle.path, payload.path, script.lastPathComponent]
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
