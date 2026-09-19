import Foundation

/// Answers a group's `GroupQuery` against the servers that exist right now.
///
/// Resolution is eager: the answer is written back into `memberIDs`, so every
/// consumer — the profile builders, the routing targets, the control API, the
/// list — keeps reading the one field it always read, and an automatic group is
/// indistinguishable from a hand-picked one once it has been resolved. The
/// store re-runs this whenever the set of servers or the annotations change.
enum GroupResolver {

    /// A server together with the source it came from, which is the one thing
    /// a `ProxyConfig` does not carry.
    struct Candidate {
        var server: ProxyConfig
        var sourceID: UUID

        init(server: ProxyConfig, sourceID: UUID) {
            self.server = server
            self.sourceID = sourceID
        }
    }

    /// The ids a query selects, in the order the candidates were given — a
    /// balancer whose member order changes on every refresh drops connections
    /// for no reason.
    static func members(of query: GroupQuery,
                        in candidates: [Candidate],
                        annotations: [UUID: NodeAnnotation],
                        autoTags: Bool = false) -> [UUID] {
        candidates
            .filter { matches(query, $0, annotations[$0.server.id] ?? NodeAnnotation(),
                              autoTags) }
            .map(\.server.id)
    }

    /// Rewrites the membership of every group that has a query, and leaves the
    /// hand-picked ones exactly as they are.
    static func resolved(_ groups: [ServerGroup],
                         in candidates: [Candidate],
                         annotations: [UUID: NodeAnnotation],
                         autoTags: Bool = false) -> [ServerGroup] {
        groups.map { group in
            guard let query = group.query else { return group }
            var group = group
            group.memberIDs = members(of: query, in: candidates, annotations: annotations,
                                      autoTags: autoTags)
            // A selector pointing at a node the query no longer takes would
            // build an outbound with nothing behind it.
            if let selected = group.selectedID, !group.memberIDs.contains(selected) {
                group.selectedID = nil
            }
            return group
        }
    }

    // MARK: - One candidate

    private static func matches(_ query: GroupQuery,
                                _ candidate: Candidate,
                                _ annotation: NodeAnnotation,
                                _ autoTags: Bool) -> Bool {
        if query.excludeHidden && annotation.hidden { return false }

        if !query.sourceIDs.isEmpty,
           !query.sourceIDs.contains(candidate.sourceID) { return false }

        if !query.protocols.isEmpty,
           !query.protocols.contains(candidate.server.proto) { return false }

        if !query.tags.isEmpty {
            let wanted = Set(query.tags.map { $0.lowercased() })
            // Derived tags count: a group asking for "premium" wants the nodes
            // the provider called premium, not only the ones labelled by hand.
            let held = Set(AutoTags.all(for: candidate.server, annotation: annotation,
                                        derived: autoTags)
                            .map { $0.lowercased() })
            if held.isDisjoint(with: wanted) { return false }
        }

        if !query.countries.isEmpty {
            let name = annotation.nameOverride ?? candidate.server.name
            guard let code = NodeFacets.country(in: name, proto: candidate.server.proto),
                  query.countries.contains(where: { $0.caseInsensitiveCompare(code) == .orderedSame })
            else { return false }
        }

        let fragment = query.nameContains.trimmingCharacters(in: .whitespaces)
        if !fragment.isEmpty {
            let name = annotation.nameOverride ?? candidate.server.name
            if name.range(of: fragment, options: .caseInsensitive) == nil { return false }
        }

        return true
    }
}
