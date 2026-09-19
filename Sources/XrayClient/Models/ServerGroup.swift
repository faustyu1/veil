import Foundation

/// A named set of servers that behaves like a single outbound.
///
/// This is what lets one rule say "send Telegram through the Netherlands group"
/// while another says "send everything else through the Germany node": a group
/// is an outbound tag like any other, so `RuleTarget.group` can point at it.
///
/// `selector` keeps whichever member the user picked (and the Clash API can
/// switch it at runtime without restarting the core). `urltest` measures the
/// members and uses the fastest.
struct ServerGroup: Codable, Equatable, Identifiable {

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case selector
        case urltest

        var id: String { rawValue }
        var title: String {
            switch self {
            case .selector: return "Manual"
            case .urltest:  return "Fastest (URL test)"
            }
        }
        var subtitle: String {
            switch self {
            case .selector: return "Always the member you picked."
            case .urltest:  return "Measures members and uses the quickest."
            }
        }
    }

    var id = UUID()
    var name: String = ""
    var kind: Kind = .selector
    /// Members, in display order. IDs that no longer resolve to a server are
    /// skipped at build time rather than failing the whole profile.
    var memberIDs: [UUID] = []
    /// Selector only: the member currently in use. Nil means "the first one".
    var selectedID: UUID?
    /// URL test only.
    var testURL: String = "http://www.gstatic.com/generate_204"
    var interval: String = "3m"
    var tolerance: Int = 50
    /// Report the group as interruptible in the Clash API dashboards.
    var interruptExistingConnections: Bool = false

    init(id: UUID = UUID(), name: String = "", kind: Kind = .selector,
         memberIDs: [UUID] = [], selectedID: UUID? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.memberIDs = memberIDs
        self.selectedID = selectedID
    }

    var tag: String { ProfileTags.group(id) }

    /// The group as one connectable entry: something a list can show and a
    /// user can click.
    ///
    /// The group's own id and name carry the identity — that id is what makes
    /// the profile connect to the group rather than to a node. The first member
    /// lends its connection details, because the path that predates profiles
    /// still dials a single server, and the rest ride along as `alternates` so
    /// the row renders as the balancer it is. Nil when nothing it names is
    /// left in `servers`.
    func representative(in servers: [ProxyConfig]) -> ProxyConfig? {
        let members = memberIDs.compactMap { id in servers.first { $0.id == id } }
        guard var first = members.first else { return nil }
        first.id = id
        first.name = name
        first.alternates = Array(members.dropFirst())
        return first
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, memberIDs, selectedID, testURL, interval
        case tolerance, interruptExistingConnections
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        id = get(.id, UUID())
        name = get(.name, "")
        kind = get(.kind, .selector)
        memberIDs = get(.memberIDs, [])
        selectedID = try? c.decode(UUID.self, forKey: .selectedID)
        testURL = get(.testURL, "http://www.gstatic.com/generate_204")
        interval = get(.interval, "3m")
        tolerance = get(.tolerance, 50)
        interruptExistingConnections = get(.interruptExistingConnections, false)
    }
}
