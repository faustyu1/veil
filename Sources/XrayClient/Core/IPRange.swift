import Foundation

/// A CIDR block, parsed far enough to answer "do these two overlap?".
///
/// The TUN inbound keeps the private ranges off the tunnel, which is right
/// until a rule sends one address inside such a range through a tunnel
/// outbound — a WireGuard peer reaching a private network, say. Those packets
/// never reach the core at all, so the rule reads as broken. Deciding that
/// needs the ranges compared, not string-matched: `172.16.4.0/24` and
/// `172.16.0.0/12` are the same conflict spelled two ways.
struct IPRange: Equatable {

    /// Network address, big-endian, as a plain integer.
    let network: UInt32
    /// Prefix length in bits.
    let prefix: UInt8

    /// Parses `a.b.c.d/len`, or a bare `a.b.c.d` (treated as `/32`).
    /// IPv6 and anything else returns nil: the callers only reason about v4,
    /// and a wrong answer there is worse than no answer.
    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.contains(":") else { return nil }
        let parts = trimmed.split(separator: "/", maxSplits: 1)
        guard let address = IPRange.address(String(parts[0])) else { return nil }
        var length: UInt8 = 32
        if parts.count == 2 {
            guard let value = UInt8(parts[1]), value <= 32 else { return nil }
            length = value
        }
        prefix = length
        network = address & IPRange.mask(length)
    }

    /// True when the two blocks share at least one address — which, for CIDR,
    /// means one contains the other.
    func overlaps(_ other: IPRange) -> Bool {
        let shared = IPRange.mask(min(prefix, other.prefix))
        return network & shared == other.network & shared
    }

    /// True when every address of `other` is inside this block.
    func contains(_ other: IPRange) -> Bool {
        prefix <= other.prefix && overlaps(other)
    }

    private static func mask(_ length: UInt8) -> UInt32 {
        length == 0 ? 0 : UInt32.max << (32 - UInt32(length))
    }

    private static func address(_ text: String) -> UInt32? {
        let octets = text.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        var value: UInt32 = 0
        for octet in octets {
            guard let byte = UInt8(octet) else { return nil }
            value = (value << 8) | UInt32(byte)
        }
        return value
    }
}
