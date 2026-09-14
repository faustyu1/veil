import Foundation

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

    public static func isPort(_ value: Int) -> Bool {
        (1...65535).contains(value)
    }

    /// Only the loopback may be named as the SOCKS host: the helper must never
    /// be talked into pointing the tunnel at a remote proxy.
    public static func isLoopback(_ host: String) -> Bool {
        host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    /// Validated, de-duplicated and capped address list.
    public static func sanitizeAddresses(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard isIPv4(trimmed), !seen.contains(trimmed) else { continue }
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
