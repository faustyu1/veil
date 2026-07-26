import Foundation

/// What the user just pasted, scanned or picked.
enum AddInput: Equatable {
    /// One or more share links, or a wg-quick profile — nothing to fetch.
    case servers([ProxyConfig])
    /// A subscription URL that still has to be downloaded.
    case subscription(String)
    case unrecognized
}

/// Works out what a blob of pasted text actually is, so the UI can offer a
/// single "add" action instead of making the user classify it first.
///
/// Order matters: share links and subscription URLs live in disjoint schemes
/// (`vless://` … vs `http(s)://`), so links are tried first and a URL is only
/// considered once nothing parsed as a server.
enum AddInputClassifier {

    static func classify(_ raw: String) -> AddInput {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unrecognized }

        // A wg-quick profile pasted whole.
        if trimmed.lowercased().contains("[interface]"),
           let wireguard = LinkParser.parseWireGuardConf(trimmed) {
            return .servers([wireguard])
        }

        // Share links, one per line — or a whole base64-wrapped subscription
        // body, which some users paste instead of the URL.
        let servers = BalancerGrouper.group(SubscriptionFetcher.decode(trimmed))
        if !servers.isEmpty { return .servers(servers) }

        // A subscription URL, plain…
        if let url = subscriptionURL(trimmed) { return .subscription(url) }

        // …or base64-wrapped, the way some panels hand them out.
        if let data = LinkParser.decodeBase64(trimmed),
           let decoded = String(data: data, encoding: .utf8),
           let url = subscriptionURL(decoded.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return .subscription(url)
        }

        return .unrecognized
    }

    private static func subscriptionURL(_ text: String) -> String? {
        guard !text.contains(where: \.isNewline),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return text
    }
}
