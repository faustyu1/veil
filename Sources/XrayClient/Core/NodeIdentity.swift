import Foundation

/// What makes two separately parsed `ProxyConfig`s the same node.
///
/// A subscription refresh reparses every entry, and every parse mints a fresh
/// `id`, so the id cannot answer "is this the node the user pinned?". The
/// connection details can: a node is its protocol, where it is, and the
/// credential it answers to.
enum NodeIdentity {
    /// `proto|address|port|authKey`.
    static func key(for server: ProxyConfig) -> String {
        let auth = authKey(for: server) ?? ""
        let address = server.address.lowercased()
        return "\(server.proto.rawValue)|\(address)|\(server.port)|\(auth)"
    }

    /// The credential a node answers to: the UUID for VLESS/VMess, the password
    /// for Trojan/SS/Hysteria2/TUIC/AnyTLS, the peer public key for WireGuard.
    static func authKey(for server: ProxyConfig) -> String? {
        switch server.proto {
        case .vless, .vmess:
            return server.uuid
        case .trojan, .shadowsocks, .hysteria2, .tuic, .anytls:
            return server.password
        case .wireguard:
            return server.peerPublicKey
        }
    }
}

/// Matches a freshly fetched set of nodes against the ones already stored for
/// the same source, so that ids — and everything the user attached to them:
/// group membership, routing rule targets, the current selection, tags and
/// pinning — stay with the node they belong to.
enum NodeReconciler {

    struct Reconciled {
        var servers: [ProxyConfig]
        var groups: [ServerGroup]
    }

    /// Returns what the source just sent, in its own order, with ids that point
    /// back at what was already stored.
    ///
    /// Nodes are matched in two passes — by identity key, then by name among
    /// what is left — so a node that was renamed and a node that moved address
    /// are both recognised. Each stored node is claimed at most once, and where
    /// several stored nodes tie the earliest one wins, so the result never
    /// depends on hashing order. An incoming node that matched nothing keeps
    /// its fresh id; a stored node that nothing matched is dropped.
    ///
    /// The groups the source declares are matched by name, since that is all a
    /// panel gives them, and their members are rewritten to the ids the nodes
    /// ended up with — without that a group would name the ids of this fetch
    /// and lose every member the moment they were reconciled away.
    static func reconcile(incoming: [ProxyConfig],
                          groups: [ServerGroup] = [],
                          existing: [ProxyConfig],
                          existingGroups: [ServerGroup] = []) -> Reconciled {
        var servers = incoming
        var remap: [UUID: UUID] = [:]

        if !existing.isEmpty {
            var claimed = Set<UUID>()
            var unmatched = Array(servers.indices)
            unmatched = claim(&servers, indices: unmatched, from: existing,
                              claimed: &claimed) { NodeIdentity.key(for: $0) }
            _ = claim(&servers, indices: unmatched, from: existing,
                      claimed: &claimed) { $0.name }
            for (index, node) in servers.enumerated() where node.id != incoming[index].id {
                remap[incoming[index].id] = node.id
            }
        }

        var claimedGroups = Set<UUID>()
        let reconciledGroups = groups.map { group -> ServerGroup in
            var group = group
            group.memberIDs = group.memberIDs.map { remap[$0] ?? $0 }
            group.selectedID = group.selectedID.map { remap[$0] ?? $0 }
            if let stored = existingGroups.first(where: {
                $0.name == group.name && !claimedGroups.contains($0.id)
            }) {
                claimedGroups.insert(stored.id)
                group.id = stored.id
            }
            return group
        }

        return Reconciled(servers: servers, groups: reconciledGroups)
    }

    /// Assigns stored ids to the nodes at `indices` whose `matchKey` finds an
    /// unclaimed partner, and returns the indices still without one.
    private static func claim(_ result: inout [ProxyConfig],
                              indices: [Int],
                              from existing: [ProxyConfig],
                              claimed: inout Set<UUID>,
                              matchKey: (ProxyConfig) -> String) -> [Int] {
        var candidates: [String: [ProxyConfig]] = [:]
        for stored in existing where !claimed.contains(stored.id) {
            candidates[matchKey(stored), default: []].append(stored)
        }

        var leftover: [Int] = []
        for index in indices {
            let key = matchKey(result[index])
            guard let match = candidates[key]?.first(where: { !claimed.contains($0.id) }) else {
                leftover.append(index)
                continue
            }
            claimed.insert(match.id)
            result[index].id = match.id
        }
        return leftover
    }
}
