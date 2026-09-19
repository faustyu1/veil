import Foundation

/// Tags a node earns from what it already says about itself.
///
/// Manual labels on their own mean a fresh install has no tags at all:
/// grouping by tag shows one bucket and the tag filter is empty, so the whole
/// dimension is invisible until someone labels fifty nodes by hand. A
/// provider's names already carry the country, the protocol, the transport and
/// their own conventions, and reading them costs nothing.
///
/// Like `NodeFacets`, these are derived on demand and never stored. A provider
/// that renames a node simply produces different tags on the next draw, and a
/// name the user overrides is tagged by the name they chose.
enum AutoTags {

    /// Words providers use that actually separate one node from another. An
    /// open vocabulary would turn every node name into its own tag, which
    /// groups nothing; this is the closed set, matched whole and case-blind.
    ///
    /// The value is the tag as it is shown — lowercase, because these are
    /// words rather than codes.
    static let vocabulary: [String: String] = {
        let words = [
            "premium", "basic", "standard", "pro", "plus", "lite", "free",
            "trial", "test", "beta", "backup", "reserve", "direct", "relay",
            "bridge", "cdn", "game", "gaming", "stream", "streaming", "media",
            "ipv6", "ipv4", "nat", "dedicated", "shared", "fast", "slow",
            "home", "work", "office", "mobile", "unlim", "unlimited"
        ]
        return Dictionary(uniqueKeysWithValues: words.map { ($0, $0) })
    }()

    /// Everything this node is tagged with, the user's own labels first.
    ///
    /// The order matters for the row: what the user wrote outranks what was
    /// guessed, and only the first few fit on screen.
    ///
    /// `derived` is the user's setting. With it off this is exactly the list
    /// they wrote by hand, because a guess about someone else's naming is not
    /// something to put on every row uninvited.
    static func all(for server: ProxyConfig,
                    annotation: NodeAnnotation,
                    derived: Bool) -> [String] {
        let automatic = derived ? tags(for: server, name: annotation.nameOverride) : []
        var result: [String] = []
        var seen = Set<String>()
        for tag in annotation.tags + automatic {
            let key = tag.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(tag)
        }
        return result
    }

    /// The tags derived from the node alone.
    ///
    /// `name` overrides the node's own, so a renamed node is tagged by the
    /// name the user gave it rather than by the one the panel sent.
    static func tags(for server: ProxyConfig, name: String? = nil) -> [String] {
        var result: [String] = []
        let display = name ?? server.name

        if let country = NodeFacets.country(in: display, proto: server.proto) {
            result.append(country)
        }
        result.append(server.proto.rawValue)
        // A tag every node carries separates nothing, and plain TCP is the
        // default for most of them.
        if server.network != .tcp {
            result.append(server.network.rawValue)
        }
        if server.security == .reality {
            result.append("reality")
        }
        result.append(contentsOf: words(in: display))
        return result
    }

    /// The vocabulary words this name uses, in the order they appear.
    private static func words(in name: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        var found: [String] = []
        var seen = Set<String>()
        for token in name.components(separatedBy: separators) where !token.isEmpty {
            let key = token.lowercased()
            guard let tag = vocabulary[key], !seen.contains(key) else { continue }
            seen.insert(key)
            found.append(tag)
        }
        return found
    }
}
