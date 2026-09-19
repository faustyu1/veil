import XCTest
@testable import XrayClient

/// A group whose membership is a question rather than a list.
///
/// A hand-picked group goes stale the moment a provider adds a node: the
/// twelfth Netherlands server is not in the "Netherlands" group because nobody
/// put it there. An automatic group states what it wants — this source, that
/// country, that tag — and is answered again every time the list changes, so a
/// refresh that brings new nodes brings them into the group too.
final class AutoGroupTests: XCTestCase {

    // MARK: - What a query matches

    func testAnEmptyQueryTakesEverything() {
        let query = GroupQuery()
        let ids = GroupResolver.members(of: query,
                                        in: [candidate("NL-01", source: panelA),
                                             candidate("DE-01", source: panelB)],
                                        annotations: [:])

        XCTAssertEqual(ids.count, 2)
    }

    func testASourceQueryTakesOnlyThatSource() {
        var query = GroupQuery()
        query.sourceIDs = [panelA]
        let nl = candidate("NL-01", source: panelA)
        let ids = GroupResolver.members(of: query,
                                        in: [nl, candidate("DE-01", source: panelB)],
                                        annotations: [:])

        XCTAssertEqual(ids, [nl.server.id])
    }

    func testACountryQueryReadsTheNodeName() {
        var query = GroupQuery()
        query.countries = ["NL"]
        let nl = candidate("🇳🇱 Amsterdam", source: panelA)
        let ids = GroupResolver.members(of: query,
                                        in: [nl, candidate("🇩🇪 Berlin", source: panelA)],
                                        annotations: [:])

        XCTAssertEqual(ids, [nl.server.id])
    }

    func testATagQueryReadsTheUsersOwnLabels() {
        let work = candidate("NL-01", source: panelA)
        let other = candidate("NL-02", source: panelA)
        var query = GroupQuery()
        query.tags = ["work"]

        let ids = GroupResolver.members(of: query, in: [work, other],
                                        annotations: [work.server.id:
                                                        NodeAnnotation(tags: ["work"])])

        XCTAssertEqual(ids, [work.server.id])
    }

    func testAProtocolQueryKeepsOnlyThatProtocol() {
        var wg = candidate("Home", source: panelA)
        wg.server.proto = .wireguard
        var query = GroupQuery()
        query.protocols = [.wireguard]

        let ids = GroupResolver.members(of: query,
                                        in: [wg, candidate("NL-01", source: panelA)],
                                        annotations: [:])

        XCTAssertEqual(ids, [wg.server.id])
    }

    func testTwoKindsOfCriterionAreBothRequired() {
        var query = GroupQuery()
        query.sourceIDs = [panelA]
        query.countries = ["NL"]

        let ids = GroupResolver.members(of: query,
                                        in: [candidate("🇳🇱 Amsterdam", source: panelB),
                                             candidate("🇩🇪 Berlin", source: panelA)],
                                        annotations: [:])

        XCTAssertTrue(ids.isEmpty, "source and country are AND-ed, not OR-ed")
    }

    func testSeveralValuesOfOneKindAreAlternatives() {
        var query = GroupQuery()
        query.countries = ["NL", "DE"]

        let ids = GroupResolver.members(of: query,
                                        in: [candidate("🇳🇱 Amsterdam", source: panelA),
                                             candidate("🇩🇪 Berlin", source: panelA),
                                             candidate("🇫🇷 Paris", source: panelA)],
                                        annotations: [:])

        XCTAssertEqual(ids.count, 2)
    }

    func testANameFragmentMatchesCaseInsensitively() {
        var query = GroupQuery()
        query.nameContains = "premium"
        let hit = candidate("NL Premium 01", source: panelA)

        let ids = GroupResolver.members(of: query,
                                        in: [hit, candidate("NL Basic 01", source: panelA)],
                                        annotations: [:])

        XCTAssertEqual(ids, [hit.server.id])
    }

    func testAHiddenNodeIsLeftOutByDefault() {
        let hidden = candidate("NL-01", source: panelA)
        let ids = GroupResolver.members(of: GroupQuery(), in: [hidden],
                                        annotations: [hidden.server.id:
                                                        NodeAnnotation(hidden: true)])

        XCTAssertTrue(ids.isEmpty,
                      "a node the user took out of the list is not a balancer member")
    }

    func testAHiddenNodeCanBeAskedForExplicitly() {
        let hidden = candidate("NL-01", source: panelA)
        var query = GroupQuery()
        query.excludeHidden = false

        let ids = GroupResolver.members(of: query, in: [hidden],
                                        annotations: [hidden.server.id:
                                                        NodeAnnotation(hidden: true)])

        XCTAssertEqual(ids, [hidden.server.id])
    }

    func testMembersKeepTheOrderTheyWereGivenIn() {
        let first = candidate("NL-01", source: panelA)
        let second = candidate("NL-02", source: panelA)
        let ids = GroupResolver.members(of: GroupQuery(), in: [first, second],
                                        annotations: [:])

        XCTAssertEqual(ids, [first.server.id, second.server.id],
                       "a reshuffled balancer reconnects for no reason")
    }

    // MARK: - Resolving a store's groups

    func testAnAutomaticGroupHasItsMembersRewritten() {
        var query = GroupQuery()
        query.countries = ["NL"]
        var group = ServerGroup(name: "Netherlands", kind: .urltest)
        group.query = query
        let nl = candidate("🇳🇱 Amsterdam", source: panelA)

        let resolved = GroupResolver.resolved([group],
                                              in: [nl, candidate("🇩🇪 Berlin", source: panelA)],
                                              annotations: [:])

        XCTAssertEqual(resolved[0].memberIDs, [nl.server.id])
    }

    func testAHandPickedGroupIsLeftAlone() {
        let stale = UUID()
        let group = ServerGroup(name: "Work", kind: .selector, memberIDs: [stale])

        let resolved = GroupResolver.resolved([group],
                                              in: [candidate("NL-01", source: panelA)],
                                              annotations: [:])

        XCTAssertEqual(resolved[0].memberIDs, [stale],
                       "without a query the list is the user's, however stale")
    }

    func testANewNodeJoinsAnAutomaticGroupOnItsOwn() {
        var query = GroupQuery()
        query.sourceIDs = [panelA]
        var group = ServerGroup(name: "Panel A", kind: .urltest)
        group.query = query
        let before = [candidate("NL-01", source: panelA)]
        let after = before + [candidate("NL-02", source: panelA)]

        let first = GroupResolver.resolved([group], in: before, annotations: [:])
        let second = GroupResolver.resolved([group], in: after, annotations: [:])

        XCTAssertEqual(first[0].memberIDs.count, 1)
        XCTAssertEqual(second[0].memberIDs.count, 2)
    }

    func testASelectionThatIsNoLongerAMemberIsDropped() {
        let gone = UUID()
        var group = ServerGroup(name: "Panel A", kind: .selector, selectedID: gone)
        group.query = GroupQuery()
        let live = candidate("NL-01", source: panelA)

        let resolved = GroupResolver.resolved([group], in: [live], annotations: [:])

        XCTAssertNil(resolved[0].selectedID,
                     "a selector pointing at nothing would build an empty outbound")
    }

    func testASelectionThatSurvivesIsKept() {
        let live = candidate("NL-01", source: panelA)
        var group = ServerGroup(name: "Panel A", kind: .selector, selectedID: live.server.id)
        group.query = GroupQuery()

        let resolved = GroupResolver.resolved([group], in: [live], annotations: [:])

        XCTAssertEqual(resolved[0].selectedID, live.server.id)
    }

    // MARK: - Round trip

    func testAQueryIsStoredWithItsGroup() throws {
        var query = GroupQuery()
        query.countries = ["NL"]
        query.tags = ["work"]
        var group = ServerGroup(name: "Netherlands", kind: .urltest)
        group.query = query

        let data = try JSONEncoder().encode(group)
        let back = try JSONDecoder().decode(ServerGroup.self, from: data)

        XCTAssertEqual(back.query, query)
    }

    func testAGroupWrittenByAnOlderBuildStillLoads() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Work","kind":"selector","memberIDs":[]}
        """
        let back = try JSONDecoder().decode(ServerGroup.self,
                                            from: Data(json.utf8))

        XCTAssertNil(back.query, "no query means the membership is hand-picked")
        XCTAssertEqual(back.name, "Work")
    }

    // MARK: - A group that matches nothing

    func testARuleNamingAnEmptyGroupDoesNotNameAMissingOutbound() throws {
        // An automatic group can legitimately match nothing — a subscription
        // expires, a country drops out — and the profile is still built.
        var node = ProxyConfig(name: "NL-01", proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = UUID().uuidString
        var group = ServerGroup(name: "Nothing", kind: .urltest)
        group.query = GroupQuery(countries: ["ZZ"])

        var profile = SingBoxProfile()
        profile.servers = [node]
        profile.groups = [group]
        profile.defaultTarget = .server(node.id)
        var rule = RoutingRule()
        rule.domains = ["example.com"]
        rule.target = .group(group.id)
        profile.rules = [rule]

        let built = SingBoxProfileBuilder.build(profile)
        let tags = Set(((built["outbounds"] as? [[String: Any]]) ?? []).compactMap { $0["tag"] as? String })
        let rules = ((built["route"] as? [String: Any])?["rules"] as? [[String: Any]]) ?? []

        for entry in rules {
            guard let outbound = entry["outbound"] as? String else { continue }
            XCTAssertTrue(tags.contains(outbound),
                          "rule sends traffic to \(outbound), which no outbound declares")
        }
    }

    // MARK: - Helpers

    private let panelA = UUID()
    private let panelB = UUID()

    private func candidate(_ name: String, source: UUID) -> GroupResolver.Candidate {
        var node = ProxyConfig(name: name, proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = UUID().uuidString
        return GroupResolver.Candidate(server: node, sourceID: source)
    }
}
