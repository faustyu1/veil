import Foundation

/// What an automatic group asks for, instead of naming its members.
///
/// A hand-picked group is a list of ids, and a list of ids is out of date the
/// moment the provider adds a node: the twelfth Netherlands server is not in
/// the "Netherlands" group because nobody put it there. A query states the
/// intent — this source, that country, that tag — and is answered again
/// whenever the list changes.
///
/// Criteria of different kinds are AND-ed; several values of one kind are
/// alternatives. "Panel A, in the Netherlands or Germany" is two kinds, one of
/// which has two values.
struct GroupQuery: Codable, Equatable {

    /// Subscriptions to draw from. Empty means every source, manual included.
    var sourceIDs: [UUID] = []
    /// The user's own labels, from `NodeAnnotation`.
    var tags: [String] = []
    /// ISO country codes, read out of the node's name by `NodeFacets`.
    var countries: [String] = []
    var protocols: [ProxyProtocol] = []
    /// A fragment of the name, matched case-insensitively. This is what a
    /// provider's own convention — `Premium`, `IPv6`, `game` — is caught with.
    var nameContains: String = ""
    /// Nodes the user hid are left out: taking a node out of the list and
    /// still routing through it is not what hiding means.
    var excludeHidden: Bool = true

    /// Whether this asks for anything at all. An empty query is "every node",
    /// which is a legitimate and useful group — the `proxy-out` of a
    /// sing-box-launcher profile — so this is for wording, not for validity.
    var isEverything: Bool {
        sourceIDs.isEmpty && tags.isEmpty && countries.isEmpty && protocols.isEmpty
            && nameContains.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case sourceIDs, tags, countries, protocols, nameContains, excludeHidden
    }

    init(sourceIDs: [UUID] = [], tags: [String] = [], countries: [String] = [],
         protocols: [ProxyProtocol] = [], nameContains: String = "",
         excludeHidden: Bool = true) {
        self.sourceIDs = sourceIDs
        self.tags = tags
        self.countries = countries
        self.protocols = protocols
        self.nameContains = nameContains
        self.excludeHidden = excludeHidden
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        sourceIDs = get(.sourceIDs, [])
        tags = get(.tags, [])
        countries = get(.countries, [])
        protocols = get(.protocols, [])
        nameContains = get(.nameContains, "")
        excludeHidden = get(.excludeHidden, true)
    }
}
