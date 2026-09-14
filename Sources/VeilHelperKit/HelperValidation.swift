import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Input validation for everything that crosses the privilege boundary.
///
/// The helper runs as root, so it treats every value from the app as hostile
/// even though the connection is already restricted to a pinned client: a bug
/// in the app should not become a root bug.
public enum HelperValidation {

    /// Upper bound on how many addresses one call may pin. A subscription with
    /// thousands of nodes must not be able to turn one call into thousands of
    /// `route` invocations.
    public static let maxAddresses = 64

    /// Strict dotted-quad IPv4. No hostnames, no ranges, no CIDR: the helper
    /// only ever pins single hosts.
    public static func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        for part in parts {
            guard !part.isEmpty, part.count <= 3,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(part), number <= 255 else { return false }
            // Reject leading zeros: `010` is octal to some resolvers.
            if part.count > 1 && part.first == "0" { return false }
        }
        return true
    }

    /// IPv6 literal without a caller-controlled scope/interface suffix.
    public static func isIPv6(_ value: String) -> Bool {
        guard !value.contains("%") else { return false }
        var address = in6_addr()
        return value.withCString { inet_pton(AF_INET6, $0, &address) } == 1
    }

    public static func isPort(_ value: Int) -> Bool {
        (1...65535).contains(value)
    }

    /// Only the loopback may be named as the SOCKS host: the helper must never
    /// be talked into pointing the tunnel at a remote proxy.
    public static func isLoopback(_ host: String) -> Bool {
        host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    public static func isInterfaceName(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 16
            && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// Validated, de-duplicated and capped address list.
    public static func sanitizeAddresses(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard (isIPv4(trimmed) || isIPv6(trimmed)), !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
            if result.count == maxAddresses { break }
        }
        return result
    }

    /// Resolvers to hand the system. Same rules as any other address, plus a
    /// small cap — macOS ignores anything past the first few anyway.
    public static func sanitizeResolvers(_ values: [String]) -> [String] {
        Array(sanitizeAddresses(values).prefix(4))
    }

    /// Accept only the two narrow requirement shapes emitted by the installer.
    /// A valid-but-broad root-owned requirement (for example `anchor apple`) is
    /// still unsafe and must not authorize an XPC client.
    public static func isAllowedClientRequirement(_ value: String) -> Bool {
        guard !value.contains("\n"), value.count <= 1024 else { return false }
        let teamPrefix = #"anchor apple generic and identifier "dev.local.veil" and certificate leaf[subject.OU] = ""#
        let hashPrefix = #"identifier "dev.local.veil" and cdhash H""#

        if value.hasPrefix(teamPrefix), value.hasSuffix("\"") {
            let token = value.dropFirst(teamPrefix.count).dropLast()
            return !token.isEmpty && token.count <= 64
                && token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        }
        if value.hasPrefix(hashPrefix), value.hasSuffix("\"") {
            let hash = value.dropFirst(hashPrefix.count).dropLast()
            return hash.count == 40 && hash.allSatisfy { $0.isHexDigit }
        }
        return false
    }
}

/// Deterministic route policy shared with tests. In strict mode the active
/// tunnel's IPv4 /2 routes are more specific than the persistent reject /1s.
/// If the interface disappears, the /1s still beat the physical default /0.
public enum TunnelRoutePolicy {
    public static let ordinaryIPv4 = ["0.0.0.0/1", "128.0.0.0/1"]
    public static let strictFallbackIPv4 = ordinaryIPv4
    public static let strictTunnelIPv4 = [
        "0.0.0.0/2", "64.0.0.0/2", "128.0.0.0/2", "192.0.0.0/2",
    ]
    public static let protectedIPv6 = ["::/1", "8000::/1"]
}

public enum KillSwitchRules {
    public static func render(physicalInterface: String, tunnelInterface: String,
                              endpointIPs: [String]) -> String? {
        guard HelperValidation.isInterfaceName(physicalInterface),
              HelperValidation.isInterfaceName(tunnelInterface) else { return nil }
        let endpoints = HelperValidation.sanitizeAddresses(endpointIPs)
        guard !endpoints.isEmpty else { return nil }

        var lines = [
            "pass out quick on lo0 all",
            "pass out quick on \(tunnelInterface) all",
            "pass out quick on \(physicalInterface) inet proto udp from any port 68 to any port 67",
            "pass out quick on \(physicalInterface) inet6 proto udp from any port 546 to any port 547",
            "pass out quick on \(physicalInterface) inet6 proto icmp6 all",
        ]
        lines += endpoints.map { "pass out quick on \(physicalInterface) to \($0)" }
        lines.append("block drop out quick all")
        return lines.joined(separator: "\n") + "\n"
    }
}

/// The command line the helper starts `tun2socks` with.
///
/// It lives here, beside the validation, because getting it wrong is silent:
/// tun2socks answers an unparseable argument by printing its usage and exiting,
/// and all the helper sees is an interface that never appeared.
public enum Tun2socksArguments {

    /// tun2socks 2.7 parses POSIX-style flags, so every long name needs two
    /// dashes — `-device` is read as the shorthand `-d` with the value
    /// `evice`, which starts nothing.
    public static func build(device: String,
                             socksHost: String,
                             socksPort: Int,
                             interface: String) -> [String] {
        [
            "--device", device,
            "--proxy", "socks5://\(socksHost):\(socksPort)",
            "--interface", interface,
        ]
    }
}
